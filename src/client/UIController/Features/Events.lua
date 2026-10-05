-- Seasonal server events (autumn, winter ...): recolours the grass and trees with a ripple from the
-- middle of the island, changes the lighting, shows a big announcement that shrinks into the event
-- banner, and spawns falling leaves / snow / rising embers around the player.
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Sound = require(Core.Sound)
local Screen = require(Core.Screen)
local VFX = require(Core.VFX)
local WorldFX = require(Core.WorldFX)

local Config, player = Context.Config, Context.Player
local tween, seq, BACK, QUAD, IN = Util.tween, Util.seq, Util.BACK, Util.QUAD, Util.IN
local WHITE, BLACK, RED = Util.WHITE, Util.BLACK, Util.RED
local Banner, FX = Context.Gui.EventBanner, Context.Gui.FX
local DEFAULT_GRASS = Color3.fromRGB(90, 200, 80)

local Events = {}

local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local baseTint = colorCorrection and colorCorrection.TintColor or WHITE
local baseClock = Lighting.ClockTime
local currentEvent, currentEventName

---------------------------------------------------------------- recolouring the island
-- every grass square, rim and tree leaf on the islands, with its normal colour
local grassParts = {}
local LEAF_REFERENCE = {Leaves = 148 / 255, PineLeaves = 125 / 255} -- leaves keep their light/dark shading
local RECOLOR = {Grass = true, Rim = true, Leaves = true, PineLeaves = true}

local function grassTarget(entry, event)
	local color = event and event.Grass and event.Grass[entry.role]
	if not color then return entry.base end
	local f = entry.shade
	return f and Color3.new(math.min(color.R * f, 1), math.min(color.G * f, 1), math.min(color.B * f, 1)) or color
end

local function addGrass(d)
	if not d:IsA("BasePart") or not RECOLOR[d.Name] then return end
	local role = d.Name == "Grass" and (d.Color.G > 0.65 and "Light" or "Dark") or d.Name
	local entry = {
		part = d,
		role = role,
		base = d.Color,
		shade = LEAF_REFERENCE[role] and d.Color.G / LEAF_REFERENCE[role],
		dist = Vector2.new(d.Position.X, d.Position.Z).Magnitude, -- for the ripple delay
	}
	table.insert(grassParts, entry)
	d.Color = grassTarget(entry, currentEvent)
end

local function applyEvent(event, animate)
	WorldFX.GrassColor = event and event.Grass and event.Grass.Light or DEFAULT_GRASS
	-- grass: a white-flash ripple spreading out from the middle of the main island
	for _, e in ipairs(grassParts) do
		local target = grassTarget(e, event)
		if animate then
			task.delay(e.dist / 110, function()
				tween(e.part, 0.1, {Color = target:Lerp(WHITE, 0.6)})
				task.delay(0.1, function() tween(e.part, 0.45, {Color = target}) end)
			end)
		else
			e.part.Color = target
		end
	end
	-- lighting
	local l = event and event.Lighting or {}
	local t = animate and 3 or 0.01
	if colorCorrection then tween(colorCorrection, t, {TintColor = l.Tint or baseTint}) end
	tween(Lighting, t, {ClockTime = l.ClockTime or baseClock})
	-- banner
	if event then
		Banner.Tile.Icon.Image = event.Icon
		Banner.Tile.UIGradient.Color = seq({event.Colors[1], event.Colors[2]:Lerp(BLACK, 0.35)})
		Banner.Title.Text = event.Title
		Banner.Title.TitleGradient.Color = seq({WHITE:Lerp(event.Colors[1], 0.35), event.Colors[1]})
		Banner.Boost.Text = event.BoostText or ""
	end
end

---------------------------------------------------------------- announcement
local function announce(event)
	local uiScale = Screen.Scale
	local y = 0.3
	local items = {}
	local function label(text, size, yOffset, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.Text = text
		l.TextColor3 = color or WHITE
		l.TextSize = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Size = UDim2.fromOffset(1400, 140)
		l.Position = UDim2.new(0.5, 0, y, yOffset * uiScale)
		l.ZIndex = 8
		local st = Instance.new("UIStroke"); st.Thickness = 5 * uiScale; st.Parent = l
		l.Parent = FX
		table.insert(items, l)
		tween(l, 0.5, {TextSize = size * uiScale}, BACK)
		return l
	end

	local rays = Instance.new("ImageLabel")
	rays.BackgroundTransparency = 1
	rays.Image = Context.Gui.PurchasePopup.BurstRays.Image
	rays.ImageColor3 = event.Colors[1]
	rays.ImageTransparency = 0.3
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.new(0.5, 0, y, -40 * uiScale)
	rays.Size = UDim2.new()
	rays.ZIndex = 6
	rays.Parent = FX
	tween(rays, 0.6, {Size = UDim2.fromOffset(760 * uiScale, 760 * uiScale)}, BACK)

	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = event.Icon
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, 0, y, -120 * uiScale)
	icon.Size = UDim2.new()
	icon.Rotation = -180
	icon.ZIndex = 9
	icon.Parent = FX
	tween(icon, 0.6, {Size = UDim2.fromOffset(140 * uiScale, 140 * uiScale), Rotation = 0}, BACK)

	local title = label(event.Title .. "!", 100, 0)
	local g = Instance.new("UIGradient"); g.Rotation = 90; g.Color = seq({WHITE:Lerp(event.Colors[1], 0.3), event.Colors[1], event.Colors[2]}); g.Parent = title
	local minutes = math.floor((event.Duration or Config.Events.Duration) / 60 + 0.5)
	task.delay(0.25, function()
		if event.BoostText then
			label(event.BoostText .. " FOR " .. minutes .. " MINUTES!", 38, 70, Color3.fromRGB(155, 255, 110))
		end
	end)
	Sound.play("Swipe", 0.85)
	Sound.play("Unlock")

	local spin = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		rays.Rotation = (t * 30) % 360
		icon.Rotation = math.sin(t * 3) * 10
		title.Rotation = math.sin(t * 2.5) * 2
	end)

	-- after a moment everything shrinks into the banner
	task.delay(2.6, function()
		local target = Util.centerOf(Banner.Tile)
		local dest = UDim2.fromOffset(target.X, target.Y)
		tween(rays, 0.45, {Size = UDim2.new(), Position = dest}, BACK, IN)
		tween(icon, 0.45, {Size = UDim2.fromOffset(58 * uiScale, 58 * uiScale), Position = dest}, QUAD, IN)
		for _, l in ipairs(items) do
			tween(l, 0.4, {TextSize = 1, Position = dest, TextTransparency = 1}, BACK, IN)
		end
		task.delay(0.45, function()
			spin:Disconnect()
			rays:Destroy()
			icon:Destroy()
			for _, l in ipairs(items) do l:Destroy() end
			Banner.Tile.Bounce.Scale = 1.45
			tween(Banner.Tile.Bounce, 0.5, {Scale = 1}, BACK)
			Banner.Title.TextSize = 40
			tween(Banner.Title, 0.4, {TextSize = 30}, BACK)
			VFX.burst(Banner, 10)
			Sound.play("Pop", 1.2)
		end)
	end)
end

local function onEventChanged(animate)
	local event, name = Config.GetEvent()
	if not event or name == currentEventName then return end
	currentEvent, currentEventName = event, name
	applyEvent(event, animate)
	if animate then announce(event) end
end

---------------------------------------------------------------- weather particles
-- falling leaves / snow / petals, rising embers (little stud parts around you)
local MAX_PARTICLES = 220
local particleCount, particleAcc = 0, 0
local GROUND_Y = Config.Hole.Center.Y

local function spawnParticle(p, center)
	local kind = p.Kind
	local size
	if kind == "Snow" then
		size = Vector3.one * (0.35 + math.random() * 0.35)
	elseif kind == "Ember" then
		size = Vector3.one * (0.25 + math.random() * 0.3)
	else
		size = Vector3.new(0.9 + math.random() * 0.6, 0.2, 0.6 + math.random() * 0.4)
	end
	-- sqrt keeps the spread even across the circle instead of bunching in the middle
	local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * 75
	local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
	local from, to, time
	if kind == "Ember" then
		from = Vector3.new(x, GROUND_Y + 0.5, z)
		to = from + Vector3.new(math.random(-4, 4), 22 + math.random() * 18, math.random(-4, 4))
		time = 2.5 + math.random() * 2
	else
		local drift = kind == "Snow" and 4 or 16
		from = Vector3.new(x, center.Y + 30 + math.random() * 20, z)
		to = Vector3.new(x + (math.random() - 0.3) * drift, GROUND_Y + size.Y / 2, z + (math.random() - 0.5) * drift)
		time = (kind == "Snow" and 5 or 4) + math.random() * 2.5
	end
	local part = WorldFX.studPart(size, p.Colors[math.random(#p.Colors)], CFrame.new(from) * WorldFX.randomAngles(), kind == "Ember" and 0.15 or 0)
	particleCount += 1
	local endCF = CFrame.new(to) * (kind == "Ember" and WorldFX.randomAngles() or CFrame.Angles(0, math.random() * 6.3, 0))
	tween(part, time, {CFrame = endCF}, kind == "Ember" and QUAD or Enum.EasingStyle.Linear)
	local linger = kind == "Ember" and 0 or 1.2 -- leaves/snow sit on the ground for a moment
	task.delay(time + linger - 0.5, function()
		tween(part, 0.5, {Transparency = 1, Size = size * 0.3})
	end)
	task.delay(time + linger, function()
		part:Destroy()
		particleCount -= 1
	end)
end

function Events.start()
	local island = workspace:WaitForChild("SkyIsland")
	for _, d in ipairs(island:GetDescendants()) do addGrass(d) end
	island.DescendantAdded:Connect(addGrass) -- streaming can load parts in later

	workspace:GetAttributeChangedSignal("Event"):Connect(function() onEventChanged(true) end)
	onEventChanged(false)

	local camera = workspace.CurrentCamera
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		Banner.Tile.EventRays.Rotation = (now * 25) % 360
		Banner.Tile.Icon.Rotation = math.sin(now * 2) * 8
		local left = math.max(0, math.floor((workspace:GetAttribute("EventEnds") or 0) - workspace:GetServerTimeNow()))
		Banner.Timer.Text = string.format("%d:%02d", left // 60, left % 60)
		Banner.Timer.TextColor3 = left <= 10 and (math.floor(now * 4) % 2 == 0 and RED or WHITE) or WHITE -- flashes in the last 10s

		local p = currentEvent and currentEvent.Particle
		if not p then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local center = root and root.Position or camera.Focus.Position
		-- accumulate fractional particles so the rate is right at any frame rate
		particleAcc += dt * p.Rate
		while particleAcc >= 1 do
			particleAcc -= 1
			if particleCount < MAX_PARTICLES then spawnParticle(p, center) end
		end
	end)
end

return Events
