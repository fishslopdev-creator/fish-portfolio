-- Upgrades menu: one card per Config.Upgrades entry. Holding the buy button keeps buying,
-- faster and faster, with a rising "level up" sound.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Sound = require(Core.Sound)
local Buttons = require(Core.Buttons)
local Toasts = require(Core.Toasts)
local Menus = require(Core.Menus)
local Screen = require(Core.Screen)
local VFX = require(Core.VFX)

local Config, Remotes, Upgrades = Context.Config, Context.Remotes, Context.Upgrades
local Money = Context.Money
local tween, BACK, RED = Util.tween, Util.BACK, Util.RED

local UpgradeMenu = Context.Gui.UpgradeMenu
local upBtn = Context.Gui.RightHUD.UpgradeButton
local upWin = UpgradeMenu.Window

local Upgrade = {}

local cards = {} -- upgrade id -> card frame

local function updateCard(u, animate)
	local card = cards[u.Id]
	local level = Upgrades[u.Id].Value
	local maxed = level >= u.Max
	card.Tile.Level.Text = maxed and "MAX" or "LV " .. level
	local now = u.Format(u.Value(level))
	if maxed then
		card.Stat.Text = now .. '\n<font color="#FFE65A">MAXED</font>'
	else
		card.Stat.Text = now .. '\n<font color="#9BFF6E">> ' .. u.Format(u.Value(level + 1)) .. "</font>"
	end
	local buyText = card.Buy:FindFirstChild("Text")
	if maxed then
		buyText.Text = "MAXED"
		card.Buy.UIGradient.Color = Util.BUY_MAX
	else
		local cost = Config.GetUpgradeCost(u, level)
		buyText.Text = "$" .. Util.abbreviate(cost)
		card.Buy.UIGradient.Color = Money.Value >= cost and Util.BUY_ON or Util.BUY_OFF
	end
	local fill = UDim2.fromScale(level / u.Max, 1)
	if animate then tween(card.Track.Fill, 0.45, {Size = fill}, BACK) else card.Track.Fill.Size = fill end
end

local function updateMenu()
	local any = false
	for _, u in ipairs(Config.Upgrades) do
		updateCard(u)
		local level = Upgrades[u.Id].Value
		if level < u.Max and Money.Value >= Config.GetUpgradeCost(u, level) then any = true end
	end
	upBtn.Dot.Visible = any -- something is affordable
	upWin.SubHeader.Text.Text = "Money " .. Util.formatLuck(Context.Multiplier.Value) .. "  |  Luck " .. Util.formatLuck(Context.Luck.Value)
end

-- step = how many times in a row this hold has bought (pitch and wiggle direction follow it)
local function celebrateUpgrade(u, card, step)
	local level = Upgrades[u.Id].Value
	local maxed = level >= u.Max
	local uiScale = Screen.Scale
	Sound.play("LevelUp", math.min(0.9 + step * 0.05, 1.6))
	card.Flash.BackgroundTransparency = 0.35
	tween(card.Flash, 0.4, {BackgroundTransparency = 1})
	local icon = card.Tile.Icon
	icon.Bounce.Scale = 1.5
	tween(icon.Bounce, 0.45, {Scale = 1}, BACK)
	icon.Rotation = step % 2 == 0 and 18 or -18
	tween(icon, 0.45, {Rotation = 0}, BACK)
	card.Stat.TextSize = 34
	tween(card.Stat, 0.35, {TextSize = 26}, BACK)
	local lvl = card.Tile.Level
	lvl.TextSize = 30
	tween(lvl, 0.35, {TextSize = 20}, BACK)
	VFX.burst(card, maxed and 24 or 7)
	local c = Util.centerOf(card.Buy)
	VFX.popText(c.X, c.Y - 20 * uiScale, maxed and "MAXED!" or "LEVEL UP!", maxed and Color3.fromRGB(255, 230, 90) or Color3.fromRGB(155, 255, 110), maxed and 40 or 30, 40)
	local t = Util.centerOf(card.Tile)
	VFX.popText(t.X + 34 * uiScale, t.Y - 10 * uiScale, "+1", Color3.fromRGB(255, 232, 90), 34, 30)
	if maxed then
		Sound.play("Unlock")
		upWin.Flash.BackgroundTransparency = 0.5
		tween(upWin.Flash, 0.5, {BackgroundTransparency = 1})
	end
end

local function tryBuy(u, card, step)
	local level = Upgrades[u.Id].Value
	if level >= u.Max then
		if step == 1 then Util.shake(card.Buy); Toasts.show("Already maxed!", Color3.fromRGB(255, 230, 90)) end
		return false
	end
	local ok, msg = Remotes.BuyUpgrade:InvokeServer(u.Id)
	if ok then
		updateCard(u, true)
		celebrateUpgrade(u, card, step)
	elseif step == 1 then -- only complain on the first press, not when a hold runs out of money
		Sound.play("Error")
		Util.shake(card.Buy)
		local buyText = card.Buy:FindFirstChild("Text")
		buyText.TextColor3 = RED
		tween(buyText, 0.5, {TextColor3 = Util.WHITE})
		Toasts.show(msg or "Not enough money!", RED)
	end
	return ok
end

-- hold-to-buy: each held button gets a token; letting go clears it and the loop stops
local holding = {}
local function bindHoldToBuy(u, card)
	Buttons.bind(card.Buy, function() end) -- hover / press feel; buying happens on press so it can repeat while held
	card.Buy.MouseButton1Down:Connect(function()
		local hold = {}
		holding[u.Id] = hold
		task.spawn(function()
			local step, gap = 1, 0.4
			while holding[u.Id] == hold do
				if not tryBuy(u, card, step) then break end
				step += 1
				task.wait(gap)
				gap = math.max(gap * 0.78, 0.07) -- speeds up the longer you hold
			end
		end)
	end)
	local function release() holding[u.Id] = nil end
	card.Buy.MouseButton1Up:Connect(release)
	card.Buy.MouseLeave:Connect(release)
end

function Upgrade.start()
	Menus.register(UpgradeMenu)
	Buttons.bind(upBtn, function() Menus.toggle(UpgradeMenu) end)

	for _, u in ipairs(Config.Upgrades) do
		local card = upWin[u.Id]
		cards[u.Id] = card
		bindHoldToBuy(u, card)
		Upgrades[u.Id].Changed:Connect(updateMenu)
	end
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			table.clear(holding)
		end
	end)
	Money.Changed:Connect(updateMenu)
	Context.Multiplier.Changed:Connect(updateMenu)
	Context.Luck.Changed:Connect(updateMenu)
	updateMenu()

	local steps = {}
	for _, u in ipairs(Config.Upgrades) do
		table.insert(steps, {Menus.popEntry(cards[u.Id]), Menus.popEntry(cards[u.Id].Tile)})
	end
	table.insert(steps, {Menus.slideEntry(upWin.Hint)})
	Menus.Steps[UpgradeMenu] = steps

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		upBtn.Icon.Rotation = math.sin(t * 2.2 + 3) * 6
		local d = 30 + math.sin(t * 7 + 1) * 4
		upBtn.Dot.Size = UDim2.fromOffset(d, d)
	end)
end

return Upgrade
