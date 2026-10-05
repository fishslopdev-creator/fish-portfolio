-- Opening and closing menu windows: one menu open at a time, background dim + blur, and a
-- staggered intro where each menu's elements pop / slide in one group after another.
local RunService = game:GetService("RunService")
local Context = require(script.Parent.Context)
local Util = require(script.Parent.Util)
local Sound = require(script.Parent.Sound)
local Buttons = require(script.Parent.Buttons)
local VFX = require(script.Parent.VFX)

local tween, BACK, IN = Util.tween, Util.BACK, Util.IN
local Dim = Context.Gui.Dim

local Menus = {
	Open = nil, -- the menu that's open right now (nil if none)
	Steps = {}, -- Steps[menu] = ordered intro steps; each step is a group of elements that animate in together
}

local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = workspace.CurrentCamera
Menus.Blur = blur

---------------------------------------------------------------- staggered intros
-- an element that grows in from scale 0 (needs a UIScale called "Intro" or "Bounce")
function Menus.popEntry(obj)
	return {pop = true, obj = obj, scale = obj:FindFirstChild("Intro") or obj:FindFirstChild("Bounce")}
end

-- a text element that slides up and fades in
function Menus.slideEntry(obj)
	return {obj = obj, base = obj.Position}
end

local introToken = 0 -- bumped whenever a menu opens or closes, so a stale intro stops part-way

local function prepareIntro(menu)
	for _, step in ipairs(Menus.Steps[menu] or {}) do
		for _, e in ipairs(step) do
			if e.pop then
				e.scale.Scale = 0
			else
				e.obj.Position = e.base + UDim2.fromOffset(0, 18)
				e.obj.TextTransparency = 1
				local st = e.obj:FindFirstChildOfClass("UIStroke")
				if st then st.Transparency = 1 end
			end
		end
	end
end

local function playIntro(menu)
	introToken += 1
	local token = introToken
	for i, step in ipairs(Menus.Steps[menu] or {}) do
		task.delay(0.12 + (i - 1) * 0.08, function()
			if token ~= introToken then return end
			Sound.play("Pop", math.min(0.85 + i * 0.07, 1.8)) -- rising pitch: pip, pip, pip...
			for j, e in ipairs(step) do
				task.delay((j - 1) * 0.04, function()
					if token ~= introToken then return end
					if e.pop then
						tween(e.scale, 0.45, {Scale = 1}, BACK)
					else
						tween(e.obj, 0.35, {Position = e.base, TextTransparency = 0}, BACK)
						local st = e.obj:FindFirstChildOfClass("UIStroke")
						if st then tween(st, 0.35, {Transparency = 0}) end
					end
				end)
			end
		end)
	end
end

---------------------------------------------------------------- sparkle panels
-- frames marked with a "Sparkles" attribute twinkle while their menu is open
local panelCache = {}
local function sparklePanelsOf(menu)
	if not panelCache[menu] then
		local found = {}
		for _, d in ipairs(menu.Window:GetDescendants()) do
			if d:GetAttribute("Sparkles") then table.insert(found, d) end
		end
		panelCache[menu] = found
	end
	return panelCache[menu]
end

---------------------------------------------------------------- open / close
local function setDim(on)
	if on then
		Dim.Visible = true
		tween(Dim, 0.25, {BackgroundTransparency = 0.5})
		tween(blur, 0.25, {Size = 16})
	else
		local tw = tween(Dim, 0.25, {BackgroundTransparency = 1})
		tween(blur, 0.25, {Size = 0})
		tw.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not Menus.Open then Dim.Visible = false end
		end)
	end
end

function Menus.close(menu)
	if not menu.Visible then return end
	introToken += 1
	if Menus.Open == menu then Menus.Open = nil end
	tween(menu.Window.AnimScale, 0.2, {Scale = 0}, BACK, IN).Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and Menus.Open ~= menu then menu.Visible = false end
	end)
	if not Menus.Open then setDim(false) end
end

function Menus.toggle(menu)
	if Menus.Open == menu then Menus.close(menu) return end
	if Menus.Open then Menus.close(Menus.Open) end
	Menus.Open = menu
	prepareIntro(menu)
	menu.Visible = true
	playIntro(menu)
	local win = menu.Window
	win.AnimScale.Scale = 0.5
	tween(win.AnimScale, 0.45, {Scale = 1}, BACK)
	win.Flash.BackgroundTransparency = 0.3
	tween(win.Flash, 0.5, {BackgroundTransparency = 1})
	for _, panel in ipairs(sparklePanelsOf(menu)) do VFX.burst(panel, 6) end
	setDim(true)
	Sound.play("Open")
end

-- hide a menu at startup and hook up its close button
function Menus.register(menu)
	menu.Visible = false
	Buttons.bind(menu.Window.CloseButton, function() Menus.close(menu) end)
end

---------------------------------------------------------------- per-frame animation
-- the little icons either side of a menu's sub header follow the text width and wiggle
local function placeSubIcons(sub, t)
	local w = sub.Text.TextBounds.X
	local pulse = 1 + math.sin(t * 4) * 0.08
	sub.LeftIcon.Position = UDim2.new(0.5, -w / 2 - 38, 0.5, 0)
	sub.RightIcon.Position = UDim2.new(0.5, w / 2 + 38, 0.5, 0)
	sub.LeftIcon.Rotation = math.sin(t * 2) * 15
	sub.RightIcon.Rotation = -math.sin(t * 2) * 15
	sub.LeftIcon.TextSize = 38 * pulse
	sub.RightIcon.TextSize = 38 * pulse
end

function Menus.start()
	Dim.Activated:Connect(function()
		if Menus.Open then Menus.close(Menus.Open) end
	end)

	local nextSparkle = 0
	RunService.RenderStepped:Connect(function()
		local open = Menus.Open
		if not open then return end -- nothing to animate behind a closed menu
		local t = os.clock()
		VFX.animate(t)
		placeSubIcons(open.Window.SubHeader, t)
		if t >= nextSparkle then
			nextSparkle = t + 0.12
			local panels = sparklePanelsOf(open)
			if #panels > 0 then VFX.sparkle(panels[math.random(#panels)]) end
		end
	end)
end

return Menus
