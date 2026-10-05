-- Money / Luck / Fish counters on the left of the HUD. They count up smoothly, bounce on change,
-- show a floating "+123" on gains and flash red on losses. Also the luck boost timer.
local RunService = game:GetService("RunService")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local VFX = require(Core.VFX)

local tween, BACK, QUART, IN = Util.tween, Util.BACK, Util.QUART, Util.IN
local LeftHUD = Context.Gui.LeftHUD
local player = Context.Player

local StatCounters = {}

local function floatText(parent, text, color, x)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.Text = text
	l.TextSize = 24
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Size = UDim2.fromOffset(160, 28)
	l.Position = UDim2.fromOffset(x, 4)
	l.ZIndex = 3
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Parent = l
	l.Parent = parent
	tween(l, 0.9, {Position = UDim2.fromOffset(x + 8, -26)}, QUART)
	tween(l, 0.9, {TextTransparency = 1}, Enum.EasingStyle.Quint, IN)
	tween(st, 0.9, {Transparency = 1}, Enum.EasingStyle.Quint, IN)
	task.delay(0.95, l.Destroy, l)
end

-- frame needs an "Amount" label and an "Icon"; value is the stat's NumberValue
local function bindCounter(frame, value, format, gainColor)
	local amount, icon = frame.Amount, frame.Icon
	local baseColor = amount.TextColor3
	-- tweening a NumberValue gives a smooth count-up for free
	local shown = Instance.new("NumberValue")
	shown.Value = value.Value
	amount.Text = format(shown.Value)
	shown.Changed:Connect(function(v) amount.Text = format(v) end)
	local last = value.Value
	value.Changed:Connect(function(new)
		local diff = new - last
		last = new
		tween(shown, 0.6, {Value = new}, QUART)
		amount.TextSize = 46
		tween(amount, 0.35, {TextSize = 40}, BACK)
		icon.Rotation = diff >= 0 and -24 or 12
		tween(icon, 0.45, {Rotation = -8}, BACK)
		if gainColor and diff > 0 then
			floatText(frame, "+" .. Util.abbreviate(diff), gainColor, amount.Position.X.Offset + amount.TextBounds.X + 12)
		elseif diff < 0 then
			amount.TextColor3 = Util.RED
			tween(amount, 0.5, {TextColor3 = baseColor})
		end
	end)
end

-- "x2 BOOST 4:59" under the luck counter while a bought luck boost is running
local function bindBoostTimer()
	local boostLabel = LeftHUD.LuckCounter:FindFirstChild("BoostTimer")
	if not boostLabel then return end
	local shown = false
	RunService.RenderStepped:Connect(function()
		local left = (player:GetAttribute("LuckBoostEnds") or 0) - workspace:GetServerTimeNow()
		if left > 0 then
			left = math.ceil(left)
			boostLabel.Text = "x" .. (player:GetAttribute("LuckBoostMulti") or 1) .. " BOOST " .. string.format("%d:%02d", left // 60, left % 60)
			boostLabel.Rotation = math.sin(os.clock() * 3) * 2
			if not shown then
				shown = true
				boostLabel.Visible = true
				boostLabel.Bounce.Scale = 0
				tween(boostLabel.Bounce, 0.5, {Scale = 1}, BACK)
				VFX.burst(LeftHUD.LuckCounter, 10)
			end
		elseif shown then
			shown = false
			boostLabel.Visible = false
		end
	end)
end

function StatCounters.start()
	bindCounter(LeftHUD.MoneyCounter, Context.Money, Util.abbreviate, Color3.fromRGB(120, 255, 90))
	bindCounter(LeftHUD.LuckCounter, Context.Luck, Util.formatLuck)
	bindCounter(LeftHUD.CollectedCounter, Context.Collected, Util.abbreviate, Color3.fromRGB(110, 215, 255))
	bindBoostTimer()
end

return StatCounters
