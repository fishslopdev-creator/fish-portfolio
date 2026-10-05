-- Rewards menu: a "like the game" thank-you, the group join reward, and playtime rewards that
-- unlock as you stay in the server.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Sound = require(Core.Sound)
local Buttons = require(Core.Buttons)
local Toasts = require(Core.Toasts)
local Menus = require(Core.Menus)
local Screen = require(Core.Screen)
local VFX = require(Core.VFX)
local ModelPreview = require(Core.ModelPreview)

local Config, Remotes, player = Context.Config, Context.Remotes, Context.Player
local tween, BACK, GREEN, GOLD, RED = Util.tween, Util.BACK, Util.GREEN, Util.GOLD, Util.RED

local RewardsMenu = Context.Gui.RewardsMenu
local rewardsButton = Context.Gui.LeftHUD.RewardsButton
local rw = RewardsMenu.Window
local likeCard, groupCard = rw.Like, rw.Group

local Rewards = {}

local function textOf(btn) return btn:FindFirstChild("Text") or btn:FindFirstChild("Status") end

local function celebrateAt(btn, text, color)
	local c = Util.centerOf(btn)
	VFX.popText(c.X, c.Y - 30 * Screen.Scale, text, color, 36, 60)
	VFX.burst(btn.Parent, 14)
	Sound.play("Purchase")
	Sound.play("LevelUp")
	rw.Flash.BackgroundTransparency = 0.5
	tween(rw.Flash, 0.5, {BackgroundTransparency = 1})
end

---------------------------------------------------------------- like
-- Roblox can't tell us if you liked, so this one is just a thank-you
local function bindLike()
	local liked = false
	Buttons.bind(likeCard.Buy, function()
		if liked then return end
		liked = true
		textOf(likeCard.Buy).Text = "THANKS!"
		likeCard.Buy.UIGradient.Color = Util.BUY_MAX
		likeCard.Tile.Icon.Bounce.Scale = 1.5
		tween(likeCard.Tile.Icon.Bounce, 0.5, {Scale = 1}, BACK)
		celebrateAt(likeCard.Buy, "THANK YOU!", GREEN)
	end)
end

---------------------------------------------------------------- group
local function bindGroup()
	local function update()
		local claimed = player:GetAttribute("GroupReward")
		textOf(groupCard.Buy).Text = claimed and "CLAIMED" or "CLAIM"
		groupCard.Buy.UIGradient.Color = claimed and Util.BUY_MAX or Util.BUY_ON
	end
	player:GetAttributeChangedSignal("GroupReward"):Connect(update)
	update()

	local busy = false
	Buttons.bind(groupCard.Buy, function()
		if busy or player:GetAttribute("GroupReward") then return end
		busy = true
		local ok, msg = Remotes.ClaimGroup:InvokeServer() -- the server checks group membership
		busy = false
		if ok then
			groupCard.Flash.BackgroundTransparency = 0.3
			tween(groupCard.Flash, 0.45, {BackgroundTransparency = 1})
			celebrateAt(groupCard.Buy, "+$" .. Util.abbreviate(Config.Group.Money) .. " + GROUP SCOOPER!", GOLD)
			Sound.play("Unlock")
		else
			Sound.play("Error")
			Util.shake(groupCard.Buy)
			if msg and msg ~= "" then Toasts.show(msg, RED) end
		end
	end)

	-- preview of what you get: the money amount and a spinning Group Scooper
	local holder = groupCard.Rewards
	holder.Money.Amount.Text = "$" .. Util.abbreviate(Config.Group.Money)
	local tool = ReplicatedStorage:WaitForChild("SpecialScoopers"):WaitForChild("Group Scooper")
	ModelPreview.show(holder.Scooper.Preview, tool)
end

---------------------------------------------------------------- playtime
local tiles = {}

local function bindPlaytime()
	for i, r in ipairs(Config.Playtime) do
		local btn = rw.Playtime["Reward" .. i]
		tiles[i] = btn
		btn.Amount.Text = "$" .. Util.abbreviate(r.Money)
		Buttons.bind(btn, function()
			if player:GetAttribute("Playtime_" .. i) then return end
			local ok, msg = Remotes.ClaimPlaytime:InvokeServer(i) -- the server checks the time too
			if ok then
				btn.Icon.Rotation = -30
				tween(btn.Icon, 0.5, {Rotation = 0}, BACK)
				celebrateAt(btn, "+$" .. Util.abbreviate(r.Money), GREEN)
			else
				Sound.play("Error")
				Util.shake(btn)
				if msg and msg ~= "" then Toasts.show(msg, RED) end
			end
		end)
	end

	-- counts up from when you joined
	local lastReady = 0
	local function update()
		local played = workspace:GetServerTimeNow() - (player:GetAttribute("JoinTime") or workspace:GetServerTimeNow())
		local ready = 0
		for i, r in ipairs(Config.Playtime) do
			local btn, status = tiles[i], tiles[i].Status
			local left = math.ceil(r.Minutes * 60 - played)
			if player:GetAttribute("Playtime_" .. i) then
				status.Text = "CLAIMED"
				btn.UIGradient.Color = Util.BUY_MAX
			elseif left <= 0 then
				ready += 1
				status.Text = "CLAIM!"
				btn.UIGradient.Color = Util.BUY_ON
			else
				status.Text = string.format("%d:%02d", left // 60, left % 60)
				btn.UIGradient.Color = Util.BUY_OFF
			end
		end
		rewardsButton.Dot.Visible = ready > 0 or not player:GetAttribute("GroupReward")
		if ready > lastReady then
			-- a new reward is ready: give the button a little hop
			rewardsButton.Bounce.Scale = 1.3
			tween(rewardsButton.Bounce, 0.5, {Scale = 1}, BACK)
			Sound.play("Pop", 1.3)
			Toasts.show("Playtime reward ready!", GREEN)
		end
		lastReady = ready
	end
	task.spawn(function()
		while true do
			update()
			task.wait(0.5)
		end
	end)
end

function Rewards.start()
	Menus.register(RewardsMenu)
	Buttons.bind(rewardsButton, function() Menus.toggle(RewardsMenu) end)
	bindLike()
	bindGroup()
	bindPlaytime()

	local steps = {
		{Menus.popEntry(likeCard), Menus.popEntry(likeCard.Tile)},
		{Menus.popEntry(groupCard), Menus.popEntry(groupCard.Tile), Menus.popEntry(groupCard.Rewards.Money), Menus.popEntry(groupCard.Rewards.Scooper)},
		{Menus.slideEntry(rw.PlaytimeHeader.Text)},
	}
	for i = 1, #tiles, 4 do -- playtime tiles pop in a row of 4 at a time
		local step = {}
		for j = i, math.min(i + 3, #tiles) do table.insert(step, Menus.popEntry(tiles[j])) end
		table.insert(steps, step)
	end
	Menus.Steps[RewardsMenu] = steps

	-- the gift wiggles while something's waiting to be claimed
	local giftIcon = rewardsButton.Icon
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		giftIcon.Rotation = rewardsButton.Dot.Visible and math.sin(t * 10) * 10 * math.max(0, math.sin(t * 1.5)) or 0
	end)
end

return Rewards
