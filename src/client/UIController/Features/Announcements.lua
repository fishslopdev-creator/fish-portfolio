-- Big centre-screen announcements for everyone: admin messages, chaos commands and the boss fish.
local RunService = game:GetService("RunService")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Sound = require(Core.Sound)
local Screen = require(Core.Screen)
local VFX = require(Core.VFX)

local tween, seq, BACK, IN, WHITE = Util.tween, Util.seq, Util.BACK, Util.IN, Util.WHITE
local FX = Context.Gui.FX
local BOSS_COLOR = Color3.fromRGB(200, 120, 255)
local RAYS_IMAGE = "rbxassetid://130341371819553"

local Announcements = {}

local function announceBig(title, sub, color)
	local uiScale = Screen.Scale
	local items = {}
	local function label(text, size, y, c)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.LuckiestGuy
		l.Text = text
		l.TextColor3 = c or WHITE
		l.TextSize = 1
		l.TextWrapped = true
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.new(0.5, 0, 0.3, y * uiScale)
		l.Size = UDim2.new(0.8, 0, 0, size * 2.4 * uiScale)
		l.ZIndex = 10
		local st = Instance.new("UIStroke"); st.Thickness = 4; st.Parent = l
		l.Parent = FX
		table.insert(items, l)
		tween(l, 0.5, {TextSize = size * uiScale}, BACK)
		return l
	end
	local rays = Instance.new("ImageLabel")
	rays.BackgroundTransparency = 1
	rays.Image = RAYS_IMAGE
	rays.ImageColor3 = color
	rays.ImageTransparency = 0.35
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.new(0.5, 0, 0.3, 0)
	rays.Size = UDim2.new()
	rays.ZIndex = 9
	rays.Parent = FX
	tween(rays, 0.6, {Size = UDim2.fromOffset(620 * uiScale, 620 * uiScale)}, BACK)
	local head = label(title, #title > 24 and 44 or 70, -30, color) -- long messages get smaller text
	local g = Instance.new("UIGradient"); g.Rotation = 90; g.Color = seq({WHITE, color}); g.Parent = head
	if sub then task.delay(0.2, function() label(sub, 36, 40) end) end
	Sound.play("Swipe", 0.85)
	Sound.play("Unlock")
	local spin = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		rays.Rotation = (t * 30) % 360
		head.Rotation = math.sin(t * 2.5) * 2
	end)
	task.delay(4.5, function()
		tween(rays, 0.4, {Size = UDim2.new()}, BACK, IN)
		for _, l in ipairs(items) do tween(l, 0.4, {TextSize = 1, TextTransparency = 1}, BACK, IN) end
		task.delay(0.45, function()
			spin:Disconnect()
			rays:Destroy()
			for _, l in ipairs(items) do l:Destroy() end
		end)
	end)
end

function Announcements.start()
	Context.Remotes.Announce.OnClientEvent:Connect(function(text, kind, from, sub, color)
		if kind == "Chaos" then
			announceBig(text, sub, color or Util.RED)
			VFX.shakeCamera(1.5, 0.5)
		elseif kind == "Boss" then
			announceBig("BOSS FISH!", "IT'S RAINING FISH FOR " .. Context.Config.Boss.Duration .. " SECONDS!", BOSS_COLOR)
			VFX.shakeCamera(2.5, 0.8)
		else
			announceBig(text, from and ("- " .. from) or nil, Color3.fromRGB(255, 225, 80))
		end
	end)
end

return Announcements
