-- Effects for fish in the world: drop shadows, trails and light pillars while they fall, landing
-- debris and camera shake, name tags over rare fish, and one outline around every fish.
-- Also lets go of fish over the hole on the client so they drop straight in.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Sound = require(Core.Sound)
local Toasts = require(Core.Toasts)
local Rarity = require(Core.Rarity)
local VFX = require(Core.VFX)
local WorldFX = require(Core.WorldFX)

local Config, player = Context.Config, Context.Player
local WHITE, BLACK = Util.WHITE, Util.BLACK

local FishEffects = {}

---------------------------------------------------------------- name tags
-- name tag above Epic+ fish (anything more common would just be clutter with this many fish)
local rainbowTags = {}
local function addTag(fish, body, rarity)
	local color = Rarity.Color[rarity] or WHITE
	local bb = Instance.new("BillboardGui")
	bb.Name = "FishTag"
	bb.Size = UDim2.fromOffset(170, 46)
	bb.StudsOffsetWorldSpace = Vector3.new(0, body.Size.Y / 2 + 2.6, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 75
	bb.Adornee = body
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.Text = fish.Name
	name.TextColor3 = color
	local st = Instance.new("UIStroke"); st.Thickness = 2.5; st.Parent = name
	name.Parent = bb
	if (Rarity.Order[rarity] or 1) >= 6 then -- Mythic and rarer
		local g = Instance.new("UIGradient"); g.Name = "TagRainbow"; g.Parent = name
		table.insert(rainbowTags, g)
	end
	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Position = UDim2.fromScale(0, 0.55)
	value.Size = UDim2.new(1, 0, 0.45, 0)
	value.Font = Enum.Font.FredokaOne
	value.TextScaled = true
	value.Text = rarity:upper() .. "  $" .. Util.abbreviate(fish:GetAttribute("Value") or 0)
	value.TextColor3 = Color3.fromRGB(150, 255, 110)
	local st2 = Instance.new("UIStroke"); st2.Thickness = 2; st2.Parent = value
	value.Parent = bb
	bb.Parent = fish
end

---------------------------------------------------------------- falling + landing
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function onFishAdded(fish)
	local body = fish:WaitForChild("Body", 5)
	if not body then return end
	local rarity = fish:GetAttribute("Rarity") or "Common"
	local order = Rarity.Order[rarity] or 1
	local color = Rarity.Color[rarity] or WHITE
	if order >= 4 then addTag(fish, body, rarity) end

	-- only falling fish get the drop effects (not ones already lying there when you join)
	rayParams.FilterDescendantsInstances = {fish.Parent, WorldFX.Folder, player.Character}
	local hit = workspace:Raycast(body.Position, Vector3.new(0, -200, 0), rayParams)
	if not hit or body.Position.Y - hit.Position.Y < 10 then return end
	local groundY = hit.Position.Y
	local mine = fish:GetAttribute("Owner") == player.UserId

	local shadow = WorldFX.studPart(Vector3.new(1, 0.2, 1), BLACK, CFrame.new(body.Position.X, groundY + 0.1, body.Position.Z), 0.9)
	local pillar, trail
	if order >= 3 then
		local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0, -body.Size.Z / 2); a0.Parent = body
		local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, 0, body.Size.Z / 2); a1.Parent = body
		trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(color)
		trail.LightEmission = 0.8
		trail.Lifetime = 0.4
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = body
	end
	if order >= 4 then
		-- a coloured light pillar marks where an Epic+ fish will land
		pillar = WorldFX.studPart(Vector3.new(5, 90, 5), color, CFrame.new(body.Position.X, groundY + 45, body.Position.Z), 0.7)
		if mine then
			Toasts.show("INCOMING: " .. rarity:upper() .. " " .. fish.Name:upper() .. "!", color)
			Sound.play("Swipe", 0.8)
		end
	end

	local started = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local height = body.Position.Y - groundY
		local landed = height < body.Size.Y + 1 and body.AssemblyLinearVelocity.Y > -25
		if not body.Parent or landed or os.clock() - started > 8 then
			conn:Disconnect()
			shadow:Destroy()
			if trail then task.delay(0.4, trail.Destroy, trail) end
			if pillar then
				Util.tween(pillar, 0.5, {Size = Vector3.new(0.2, 90, 0.2), Transparency = 1}, Util.QUAD, Util.IN)
				task.delay(0.5, pillar.Destroy, pillar)
			end
			if body.Parent and landed then
				local pos = Vector3.new(body.Position.X, groundY + 0.5, body.Position.Z)
				Sound.playAt("Land", pos)
				Sound.playAt("Flop", pos)
				local grass = WorldFX.GrassColor
				if order >= 3 then
					WorldFX.debris(pos, {body.Color, body.Color:Lerp(WHITE, 0.4), grass}, 6 + order, 4 + order)
				else
					WorldFX.debris(pos, {body.Color, grass}, 2, 3)
				end
				if order >= 4 then
					WorldFX.ringBlast(pos, color, 16)
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if root and (root.Position - pos).Magnitude < 70 then VFX.shakeCamera(order >= 5 and 2.2 or 1.2, 0.35) end
				end
			end
			return
		end
		-- the shadow grows and darkens as the fish gets closer to the ground
		local near = 1 - math.clamp(height / 60, 0, 1)
		local w = 1 + near * math.max(body.Size.X, body.Size.Z)
		shadow.Size = Vector3.new(w, 0.2, w)
		shadow.CFrame = CFrame.new(body.Position.X, groundY + 0.1, body.Position.Z)
		shadow.Transparency = 0.9 - near * 0.45
	end)
end

---------------------------------------------------------------- outline
-- One Highlight on the whole fish container outlines every fish at once
-- (Roblox only draws ~31 Highlights, so one per fish wouldn't work with this many).
local function addOutline(container)
	local hl = Instance.new("Highlight")
	hl.Name = "FishOutline"
	hl.FillTransparency = 1
	hl.OutlineColor = BLACK
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = container
	hl.Parent = container
end

---------------------------------------------------------------- dropping into the hole
-- Your client is usually the one simulating the fish you push (network ownership), so it lets go of
-- a fish the moment it's over the hole (no waiting for the server), so fish drop straight in
-- instead of sliding across.
local function dropFishOverHole(container)
	local hole = Config.Hole
	local down = Vector3.new(0, -3, 0)
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include
	groundParams.FilterDescendantsInstances = {workspace:WaitForChild("SkyIsland")}
	groundParams.RespectCanCollide = true
	groundParams.CollisionGroup = "PushItems" -- fish fall through the bridges
	RunService.Heartbeat:Connect(function()
		for _, fish in ipairs(container:GetChildren()) do
			local body = fish:FindFirstChild("Body")
			if body then
				local p = body.Position
				-- square ring: distance from the centre measured along whichever axis is further
				local d = math.max(math.abs(p.X - hole.Center.X), math.abs(p.Z - hole.Center.Z))
				if d > hole.Inner + 1 and d < hole.Outer - 1 and p.Y > hole.CatchY then
					local plane = body:FindFirstChildOfClass("PlaneConstraint")
					if plane and plane.Enabled and not workspace:Raycast(p, down, groundParams) then
						plane.Enabled = false
						local flat = body:FindFirstChildOfClass("AlignOrientation")
						if flat then flat.Enabled = false end
						local v = body.AssemblyLinearVelocity
						body.AssemblyLinearVelocity = Vector3.new(v.X * 0.3, -12, v.Z * 0.3)
					end
				end
			end
		end
	end)
end

function FishEffects.start()
	CollectionService:GetInstanceAddedSignal("Fish"):Connect(onFishAdded)
	for _, fish in ipairs(CollectionService:GetTagged("Fish")) do task.spawn(onFishAdded, fish) end

	task.spawn(function()
		local container = workspace:WaitForChild("Fish")
		addOutline(container)
		dropFishOverHole(container)
	end)

	-- mythic fish tags shimmer
	RunService.RenderStepped:Connect(function()
		if #rainbowTags == 0 then return end
		local rainbow = Util.rainbowSeq(os.clock())
		for i = #rainbowTags, 1, -1 do
			local g = rainbowTags[i]
			if g:IsDescendantOf(workspace) then g.Color = rainbow else table.remove(rainbowTags, i) end
		end
	end)
end

return FishEffects
