-- Trail shop, opened by talking to the Trail Guy NPC: buy, equip and unequip trails.
-- Also animates rainbow trails on every player.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Sound = require(Core.Sound)
local Buttons = require(Core.Buttons)
local Toasts = require(Core.Toasts)
local Menus = require(Core.Menus)
local Screen = require(Core.Screen)
local VFX = require(Core.VFX)

local Config, player = Context.Config, Context.Player
local tween, BACK = Util.tween, Util.BACK

local TrailMenu = Context.Gui.TrailMenu
local trailWin = TrailMenu.Window
local TRAIL_EQUIP = Util.seq({Color3.fromRGB(110, 210, 255), Color3.fromRGB(40, 120, 235)})
local WALK_AWAY_DISTANCE = 25

local TrailShop = {}

local cards = {} -- trail id -> card frame
local busy = false
local trailGuy -- the part the prompt is on, for the walk-away check

local function update()
	local equipped = player:GetAttribute("EquippedTrail")
	for _, t in ipairs(Config.Trails) do
		local card = cards[t.Id]
		local owned = player:GetAttribute("Trail_" .. t.Id)
		local label = card.Buy:FindFirstChild("Text")
		if equipped == t.Id then
			label.Text = "EQUIPPED"
			card.Buy.UIGradient.Color = Util.BUY_MAX
		elseif owned then
			label.Text = "EQUIP"
			card.Buy.UIGradient.Color = TRAIL_EQUIP
		else
			label.Text = "$" .. Util.abbreviate(t.Price)
			card.Buy.UIGradient.Color = Context.Money.Value >= t.Price and Util.BUY_ON or Util.BUY_OFF
		end
		card.UIStroke.Color = equipped == t.Id and Color3.fromRGB(255, 215, 60) or Util.BLACK
		card.UIStroke.Thickness = equipped == t.Id and 5 or 4
	end
	local current = Config.GetTrail(equipped or "")
	trailWin.SubHeader.Text.Text = "Equipped: " .. (current and current.Name or "None") .. "  |  Money " .. Util.formatLuck(Context.Multiplier.Value)
end

-- one button does all three: buy if you don't own it, equip if you do, unequip if it's on
local function onCardPressed(t, card)
	if busy then return end
	local owned = player:GetAttribute("Trail_" .. t.Id)
	local equipped = player:GetAttribute("EquippedTrail") == t.Id
	local action = equipped and "Unequip" or owned and "Equip" or "Buy"
	busy = true
	local ok, msg = Context.Remotes.TrailAction:InvokeServer(action, t.Id)
	busy = false
	local c = Util.centerOf(card.Buy)
	local uiScale = Screen.Scale
	if ok then
		card.Flash.BackgroundTransparency = 0.3
		tween(card.Flash, 0.45, {BackgroundTransparency = 1})
		card.Ribbon.Bounce.Scale = 1.25
		tween(card.Ribbon.Bounce, 0.45, {Scale = 1}, BACK)
		if action == "Buy" then
			Sound.play("Purchase")
			Sound.play("LevelUp")
			VFX.burst(card, 18)
			trailWin.Flash.BackgroundTransparency = 0.5
			tween(trailWin.Flash, 0.5, {BackgroundTransparency = 1})
			VFX.popText(c.X, c.Y - 30 * uiScale, "NEW TRAIL!", Color3.fromRGB(255, 225, 80), 36, 60)
		elseif action == "Equip" then
			Sound.play("Pop", 1.2)
			VFX.burst(card, 8)
			VFX.popText(c.X, c.Y - 30 * uiScale, "EQUIPPED!", Color3.fromRGB(110, 215, 255), 30, 50)
		else
			Sound.play("Pop", 0.8)
		end
	else
		Sound.play("Error")
		Util.shake(card.Buy)
		if msg and msg ~= "" then Toasts.show(msg, Util.RED) end
	end
end

function TrailShop.start()
	Menus.register(TrailMenu)

	for _, t in ipairs(Config.Trails) do
		local card = trailWin[t.Id]
		cards[t.Id] = card
		Buttons.bind(card.Buy, function() onCardPressed(t, card) end)
		player:GetAttributeChangedSignal("Trail_" .. t.Id):Connect(update)
	end
	player:GetAttributeChangedSignal("EquippedTrail"):Connect(update)
	Context.Money.Changed:Connect(update)
	Context.Multiplier.Changed:Connect(update)
	update()

	local steps = {}
	for _, t in ipairs(Config.Trails) do
		table.insert(steps, {Menus.popEntry(cards[t.Id]), Menus.popEntry(cards[t.Id].Ribbon)})
	end
	table.insert(steps, {Menus.slideEntry(trailWin.Hint)})
	Menus.Steps[TrailMenu] = steps

	-- open from the Trail Guy, close again if you walk away from him
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "TrailPrompt" then
			trailGuy = prompt.Parent
			if Menus.Open ~= TrailMenu then Menus.toggle(TrailMenu) end
		end
	end)

	local npcSign
	task.spawn(function()
		local npc = workspace:WaitForChild("Trail Guy", 30)
		local head = npc and npc:WaitForChild("Head", 30)
		local sign = head and head:WaitForChild("Sign", 30)
		npcSign = sign and sign.Title:FindFirstChild("Rainbow")
	end)

	RunService.RenderStepped:Connect(function()
		local rainbow = Util.rainbowSeq(os.clock())
		if npcSign then npcSign.Color = rainbow end
		-- rainbow trails on everyone wearing one
		for _, p in ipairs(Players:GetPlayers()) do
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local tr = root and root:FindFirstChild("StudTrail")
			if tr and tr:GetAttribute("Rainbow") then tr.Color = rainbow end
		end
		if TrailMenu.Visible then
			for _, card in pairs(cards) do
				local g = card.Ribbon.TrailGradient
				if g:GetAttribute("Rainbow") then g.Color = rainbow end
			end
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if Menus.Open == TrailMenu and trailGuy and root and (root.Position - trailGuy.Position).Magnitude > WALK_AWAY_DISTANCE then
				Menus.close(TrailMenu)
			end
		end
	end)
end

return TrailShop
