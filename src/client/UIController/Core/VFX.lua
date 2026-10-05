-- Screen-space effects: sparkles, pop-up text, camera shake, and the always-moving decorations
-- (light rays, shimmer sweeps, flowing gradients) found by name inside the menus.
local RunService = game:GetService("RunService")
local Context = require(script.Parent.Context)
local Util = require(script.Parent.Util)
local Screen = require(script.Parent.Screen)

local tween, BACK, QUAD, QUART, IN = Util.tween, Util.BACK, Util.QUAD, Util.QUART, Util.IN
local FX = Context.Gui.FX

local VFX = {}

---------------------------------------------------------------- sparkles
local sparkleChars = {"✦", "✧", "★"}
function VFX.sparkle(panel)
	local s = Instance.new("TextLabel")
	s.BackgroundTransparency = 1
	s.Font = Enum.Font.FredokaOne
	s.Text = sparkleChars[math.random(#sparkleChars)]
	s.TextColor3 = math.random() < 0.6 and Util.WHITE or Color3.fromRGB(255, 240, 140)
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Position = UDim2.fromScale(math.random(), math.random())
	s.Size = UDim2.fromOffset(40, 40)
	s.TextSize = 1
	s.Rotation = math.random(0, 90)
	s.ZIndex = 1
	s.Parent = panel
	tween(s, 0.35, {TextSize = math.random(16, 34), Rotation = s.Rotation + 90}, BACK)
	task.delay(0.4, function()
		tween(s, 0.45, {TextSize = 1, Rotation = s.Rotation + 90, TextTransparency = 1}, QUAD, IN)
	end)
	task.delay(0.9, s.Destroy, s)
end

function VFX.burst(panel, n)
	for _ = 1, n do
		task.delay(math.random() * 0.3, VFX.sparkle, panel)
	end
end

---------------------------------------------------------------- named decorations
-- Designers mark decorations by name in Studio ("Gleam", "Rays", "Rainbow" ...);
-- register() collects them once and animate() moves them every frame while a menu is open.
local gleams, spinners, rainbows, flows, bars = {}, {}, {}, {}, {}

function VFX.register(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d.Name == "Gleam" then
			table.insert(gleams, {d, math.random() * 3})
		elseif d.Name == "Rays" then
			table.insert(spinners, {d, d:GetAttribute("Speed") or 20, math.random() * 360})
		elseif d:IsA("UIGradient") and d.Name == "Rainbow" then
			table.insert(rainbows, d)
		elseif d:IsA("UIGradient") and d.Name == "PanelGradient" then
			table.insert(flows, {d, d.Rotation, math.random() * 6})
		elseif d:IsA("UIGradient") and d.Name == "BarGradient" then
			table.insert(bars, d)
		end
	end
end

function VFX.animate(t)
	-- spinning light rays
	for _, s in ipairs(spinners) do
		s[1].Rotation = (s[3] + t * s[2]) % 360
	end
	-- shimmer sweeps across bars and buttons
	for _, g in ipairs(gleams) do
		local p = (t + g[2]) % 3.2
		g[1].Position = UDim2.new(p < 1 and -0.2 + p * 1.4 or -0.5, 0, 0.5, 0)
	end
	-- flowing gradients
	local rainbow = Util.rainbowSeq(t)
	for _, g in ipairs(rainbows) do g.Color = rainbow end
	for _, f in ipairs(flows) do
		f[1].Rotation = f[2] + math.sin(t * 0.6 + f[3]) * 20
		f[1].Offset = Vector2.new(math.sin(t * 0.45 + f[3]) * 0.15, 0)
	end
	for _, b in ipairs(bars) do
		b.Offset = Vector2.new(math.sin(t * 1.1) * 0.2, 0)
	end
end

---------------------------------------------------------------- pop-up text
-- text that pops in at a screen position and floats upward ("LEVEL UP!", "+$1.2K" ...)
function VFX.popText(x, y, text, color, size, rise)
	local uiScale = Screen.Scale
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextColor3 = color
	l.TextSize = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = UDim2.fromOffset(400, 80)
	l.Position = UDim2.fromOffset(x, y)
	l.ZIndex = 5
	local st = Instance.new("UIStroke")
	st.Thickness = 3.5 * uiScale
	st.Parent = l
	l.Parent = FX
	tween(l, 0.3, {TextSize = (size or 30) * uiScale}, BACK)
	tween(l, 1, {Position = UDim2.fromOffset(x + math.random(-20, 20), y - (rise or 70) * uiScale)}, QUART)
	task.delay(0.55, function()
		tween(l, 0.45, {TextTransparency = 1}, QUAD, IN)
		tween(st, 0.45, {Transparency = 1}, QUAD, IN)
	end)
	task.delay(1.05, l.Destroy, l)
end

---------------------------------------------------------------- camera shake
local shakeUntil, shakePower = 0, 0

function VFX.shakeCamera(power, duration)
	shakePower = math.max(power, os.clock() < shakeUntil and shakePower or 0)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

function VFX.start()
	local camera = workspace.CurrentCamera
	-- runs right after the camera scripts, so the shake is added on top of the normal camera
	RunService:BindToRenderStep("StudShake", Enum.RenderPriority.Camera.Value + 1, function()
		local left = shakeUntil - os.clock()
		if left > 0 then
			local p = shakePower * math.min(left * 3, 1) -- fades out over the last third of a second
			camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * p), math.rad((math.random() - 0.5) * p), 0)
		end
	end)
end

return VFX
