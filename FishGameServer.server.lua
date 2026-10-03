-- Fish game: loads of fish rain onto the main island, players push them into the ring hole for money.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("StudUI")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")
local FishModels = ReplicatedStorage:WaitForChild("FishModels")
local Scoopers = ReplicatedStorage:WaitForChild("Scoopers")

-- a Model (not a Folder) so the client can outline every fish with a single Highlight
local fishFolder = Instance.new("Model")
fishFolder.Name = "Fish"
fishFolder.Parent = workspace

local rarityIndex = {}
for i, r in ipairs(Config.Rarities) do rarityIndex[r.Name] = i end

local fishInfo = {}
for _, f in ipairs(Config.Fish) do fishInfo[f.Name] = f end

-- scooper tools by tier (from the Scoopers folder, plus any kept in StarterPack)
local scooperByTier = {}
for _, folder in ipairs({Scoopers, game:GetService("StarterPack")}) do
	for _, tool in ipairs(folder:GetChildren()) do
		local tier = tool:IsA("Tool") and tool:GetAttribute("Tier")
		if tier and not scooperByTier[tier] then scooperByTier[tier] = tool end
	end
end

---------------------------------------------------------------- staying on the floor
-- Once a fish lands it's locked flat onto the floor (it can only slide and turn), so fish can't
-- climb on top of each other or over a scooper. Pushed over the hole or off an edge, it's let go.
local FLOOR_Y = Config.Hole.Center.Y
local floorAttachment = Instance.new("Attachment")
floorAttachment.Name = "FishFloor"
floorAttachment.CFrame = CFrame.fromMatrix(Vector3.new(0, FLOOR_Y, 0), Vector3.yAxis, Vector3.zAxis) -- primary axis = plane normal
floorAttachment.Parent = workspace.Terrain

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = {workspace:WaitForChild("SkyIsland")}
groundParams.RespectCanCollide = true
groundParams.CollisionGroup = "PushItems" -- so the bridges (which fish fall through) don't count as ground

-- bridges: players walk across, fish fall straight through
do
	local PhysicsService = game:GetService("PhysicsService")
	pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, "Bridges")
	PhysicsService:CollisionGroupSetCollidable("Bridges", "PushItems", false)
	PhysicsService:CollisionGroupSetCollidable("Bridges", "FallingFish", false)
	PhysicsService:CollisionGroupSetCollidable("Bridges", "Scoopers", false) -- scoopers only ever touch fish
	local island = workspace:WaitForChild("SkyIsland")
	for _, folder in ipairs({island:FindFirstChild("Bridge"), island.MainIsland:FindFirstChild("GapBridge")}) do
		for _, p in ipairs(folder and folder:GetDescendants() or {}) do
			if p:IsA("BasePart") then p.CollisionGroup = "Bridges" end
		end
	end
end

local function groundBelow(body)
	return workspace:Raycast(body.Position, Vector3.new(0, -(body.Size.Y / 2 + 1.5), 0), groundParams)
end

-- never lock a fish down inside someone's scooper wall (it would end up stuck under it)
local overlapParams = OverlapParams.new()
overlapParams.CollisionGroup = "PushItems" -- (a group that collides with scoopers, so they show up)
local function scooperIn(cf, size)
	for _, p in ipairs(workspace:GetPartBoundsInBox(cf, size, overlapParams)) do
		if p.CollisionGroup == "Scoopers" then return p end
	end
	return nil
end

-- slide a landing spot out of any scooper wall it overlaps (to whichever side is closer)
local function clearOfScoopers(spot, body)
	local radius = math.max(body.Size.X, body.Size.Z) / 2
	for _ = 1, 4 do
		local p = scooperIn(spot, body.Size)
		if not p then return spot end
		local rel = p.CFrame:PointToObjectSpace(spot.Position)
		local push
		if p.Size.X >= p.Size.Z then -- wall runs along its X, so move across its Z
			local dir = rel.Z >= 0 and 1 or -1
			push = p.CFrame:VectorToWorldSpace(Vector3.new(0, 0, dir * (p.Size.Z / 2 + radius - math.abs(rel.Z) + 0.1)))
		else
			local dir = rel.X >= 0 and 1 or -1
			push = p.CFrame:VectorToWorldSpace(Vector3.new(dir * (p.Size.X / 2 + radius - math.abs(rel.X) + 0.1), 0, 0))
		end
		spot += Vector3.new(push.X, 0, push.Z)
	end
	return not scooperIn(spot, body.Size) and spot or nil
end

-- where a fish ends up once it's laid flat on the floor
local function flatSpot(body)
	local look = body.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then look = body.CFrame.RightVector * Vector3.new(1, 0, 1) end
	local pos = Vector3.new(body.Position.X, FLOOR_Y + body.Size.Y / 2 + 0.02, body.Position.Z)
	return CFrame.lookAt(pos, pos + look)
end

local function setGroup(fish, group)
	for _, p in ipairs(fish:GetDescendants()) do
		if p:IsA("BasePart") then p.CollisionGroup = group end
	end
end

local live = {}       -- fish model -> {Owner = userId, Born = time, LastTouch = player, TouchTime = time}
local ownedCount = {} -- userId -> number of live fish
local nextSpawn = {}  -- player -> time of their next fish
local liveTotal = 0   -- fish in the whole server

local function upgradeLevel(player, id)
	local upgrades = player:FindFirstChild("Upgrades")
	local v = upgrades and upgrades:FindFirstChild(id)
	return v and v.Value or 0
end

local function upgradeValue(player, id)
	return Config.GetUpgrade(id).Value(upgradeLevel(player, id))
end

---------------------------------------------------------------- spawning
local function rollFish(luck)
	local total, weights = 0, {}
	for i, f in ipairs(Config.Fish) do
		local step = math.min((rarityIndex[f.Rarity] or 1) - 1, Config.Spawning.MaxLuckStep or math.huge)
		local w = f.Weight * luck ^ (step * Config.Spawning.LuckPower)
		weights[i] = w
		total += w
	end
	local r = math.random() * total
	for i, w in ipairs(weights) do
		r -= w
		if r <= 0 then return Config.Fish[i] end
	end
	return Config.Fish[1]
end

local function playerFromPart(part)
	local model = part:FindFirstAncestorWhichIsA("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

local function removeFish(fish)
	local data = live[fish]
	if not data then return end
	live[fish] = nil
	liveTotal -= 1
	if not data.Bonus then
		ownedCount[data.Owner] = math.max((ownedCount[data.Owner] or 1) - 1, 0)
	end
	fish:Destroy()
end

-- forced = a Config.Fish entry to drop (admin), luckMulti = extra luck, bonus = doesn't count toward their max fish
local function spawnFish(player, forced, luckMulti, bonus)
	local stats = player:FindFirstChild("Stats")
	if not stats then return end
	local info = forced or rollFish(stats.Luck.Value * Config.EventBoost("Luck") * (luckMulti or 1) * (workspace:GetAttribute("ChaosLuck") or 1))
	local template = FishModels:FindFirstChild(info.Name)
	if not template then return end

	local sp = Config.Spawning
	local angle, dist = math.random() * math.pi * 2, math.sqrt(math.random()) * sp.Radius
	local pos = sp.Center + Vector3.new(math.cos(angle) * dist, sp.DropHeight + math.random() * 10, math.sin(angle) * dist)

	local fish = template:Clone()
	fish:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.random() * math.pi * 2, 0) * CFrame.Angles(math.rad(math.random(-25, 25)), 0, math.rad(math.random(-25, 25))))
	fish:SetAttribute("Owner", player.UserId)
	fish:SetAttribute("Value", info.Value)
	fish:SetAttribute("Rarity", info.Rarity)
	CollectionService:AddTag(fish, "Fish")

	local data = {Owner = player.UserId, Born = os.clock(), Bonus = bonus}
	live[fish] = data
	liveTotal += 1
	if not bonus then ownedCount[player.UserId] = (ownedCount[player.UserId] or 0) + 1 end

	-- remember who pushed it last so they get the money
	for _, p in ipairs(fish:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then
			p.Touched:Connect(function(hit)
				local who = playerFromPart(hit)
				if who then
					data.LastTouch, data.TouchTime = who, os.clock()
				end
			end)
		end
	end

	-- floor lock (switched on when it lands)
	local body = fish.PrimaryPart
	local bottom = Instance.new("Attachment")
	bottom.Name = "FloorPoint"
	bottom.Position = Vector3.new(0, -body.Size.Y / 2, 0)
	bottom.Parent = body
	local up = Instance.new("Attachment")
	up.Name = "UpAxis"
	up.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.zAxis)
	up.Parent = body
	local plane = Instance.new("PlaneConstraint")
	plane.Attachment0, plane.Attachment1 = floorAttachment, bottom
	plane.Enabled = false
	plane.Parent = body
	local flat = Instance.new("AlignOrientation")
	flat.Mode = Enum.OrientationAlignmentMode.OneAttachment
	flat.AlignType = Enum.AlignType.PrimaryAxisParallel
	flat.PrimaryAxis = Vector3.yAxis
	flat.Attachment0 = up
	flat.RigidityEnabled = true
	flat.Enabled = false
	flat.Parent = body
	data.Plane, data.Flat = plane, flat
	setGroup(fish, "FallingFish") -- passes through other fish and scoopers while dropping

	fish.Parent = fishFolder
	body:SetNetworkOwner(nil) -- the server lands it, then players' physics takes over
	body.AssemblyAngularVelocity = Vector3.new(math.random(-3, 3), math.random(-4, 4), math.random(-3, 3))
end

local function settle(fish, data, spot)
	local body = fish.PrimaryPart
	body.AssemblyLinearVelocity = Vector3.zero
	body.AssemblyAngularVelocity = Vector3.zero
	body.CFrame = spot
	data.Plane.Enabled = true
	data.Flat.Enabled = true
	data.Settled = true
	data.NextGroundCheck = 0
	if data.Group ~= "PushItems" then
		setGroup(fish, "PushItems")
		data.Group = "PushItems"
		pcall(body.SetNetworkOwnershipAuto, body)
	end
end

local function release(fish, data)
	data.Plane.Enabled = false
	data.Flat.Enabled = false
	data.Settled = false
	data.ReleasedAt = os.clock()
	-- falling again: pass through scoopers/fish so it can't end up riding on top of one
	setGroup(fish, "FallingFish")
	data.Group = "FallingFish"
	local body = fish.PrimaryPart
	pcall(body.SetNetworkOwner, body, nil)
	-- a fish that was lying still is asleep and won't fall on its own: give it a push down
	-- (and take most of its sideways speed away so it can't sail across the hole)
	local v = body.AssemblyLinearVelocity
	body.AssemblyLinearVelocity = Vector3.new(v.X * 0.3, -12, v.Z * 0.3)
end

---------------------------------------------------------------- scoopers
local function isScooper(tool)
	return tool:IsA("Tool") and tool:GetAttribute("Tier") ~= nil
end

local groupScooper = ReplicatedStorage:WaitForChild("SpecialScoopers"):WaitForChild("Group Scooper")

local function giveScooper(player, equip)
	local stats = player:FindFirstChild("Stats")
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not stats or not character or not backpack then return end
	local tier = Config.GetScooperTier(stats.Collected.Value)
	while tier > 1 and not scooperByTier[tier] do tier -= 1 end
	local template = scooperByTier[tier]
	-- group members get the Group Scooper until their own one is better
	if player:GetAttribute("GroupReward") and tier <= Config.Group.ScooperTier then
		template = groupScooper
		tier = Config.Group.ScooperTier
	end
	if not template then return end

	-- swap out any other scooper (e.g. the one from StarterPack), keep the right one
	local wasEquipped, current = false, nil
	for _, container in ipairs({character, backpack}) do
		for _, tool in ipairs(container:GetChildren()) do
			if isScooper(tool) then
				if container == character then wasEquipped = true end
				if tool:GetAttribute("Tier") == tier and tool.Name == template.Name and not current then
					current = tool
				else
					tool:Destroy()
				end
			end
		end
	end
	local tool = current or template:Clone()
	if not current then tool.Parent = backpack end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and (equip or wasEquipped) and tool.Parent ~= character then humanoid:EquipTool(tool) end
end

---------------------------------------------------------------- collecting
local function nearestPlayer(pos, maxDist)
	local best, bestDist = nil, maxDist
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (root.Position - pos).Magnitude
			if d < bestDist then best, bestDist = p, d end
		end
	end
	return best
end

-- Fish dropped in the hole in the same moment are paid out together (one big +$ instead of 30 small ones).
local pending = {} -- collector -> list of {Name, Rarity, Payout, Pos}

local function collect(fish, pos)
	local data = live[fish]
	local info = fishInfo[fish.Name]
	if not data or not info then removeFish(fish) return end

	local collector = data.LastTouch
	if not (collector and collector.Parent and os.clock() - data.TouchTime < 20) then
		collector = nearestPlayer(pos, 60) or Players:GetPlayerByUserId(data.Owner)
	end
	removeFish(fish)
	if not collector or not collector:FindFirstChild("Stats") then return end
	pending[collector] = pending[collector] or {}
	table.insert(pending[collector], {Name = info.Name, Rarity = info.Rarity, Value = info.Value, Pos = pos})
end

local function payOut()
	for collector, list in pairs(pending) do
		local stats = collector.Parent and collector:FindFirstChild("Stats")
		if stats then
			local mult = stats.Multiplier.Value * Config.EventBoost("Money") * (workspace:GetAttribute("ChaosMoney") or 1)
			local total = 0
			local discovered = collector:FindFirstChild("Discovered")
			for _, f in ipairs(list) do
				f.Payout = math.max(math.floor(f.Value * mult + 0.5), 1)
				f.Value = nil
				total += f.Payout
				-- first time this player has ever caught this fish? (the client shows the big popup for rare ones)
				if discovered and not discovered:FindFirstChild(f.Name) then
					local v = Instance.new("BoolValue"); v.Name = f.Name; v.Value = true; v.Parent = discovered
					f.First = true
				end
			end
			local oldTier = Config.GetScooperTier(stats.Collected.Value)
			stats.Money.Value += total
			stats.Collected.Value += #list
			Remotes.FishCollected:FireAllClients(collector, list)

			local newTier = Config.GetScooperTier(stats.Collected.Value)
			if newTier > oldTier and scooperByTier[newTier] then
				giveScooper(collector, true)
				Remotes.ScooperUnlocked:FireClient(collector, scooperByTier[newTier].Name, newTier)
			end
		end
	end
	table.clear(pending)
end

local hole = Config.Hole
local function inHole(pos)
	if pos.Y > hole.CatchY then return false end
	local d = math.max(math.abs(pos.X - hole.Center.X), math.abs(pos.Z - hole.Center.Z))
	return d >= hole.Inner and d <= hole.Outer
end

---------------------------------------------------------------- upgrades
local buying = {}
Remotes.BuyUpgrade.OnServerInvoke = function(player, id)
	local upgrade = typeof(id) == "string" and Config.GetUpgrade(id)
	local stats = player:FindFirstChild("Stats")
	local upgrades = player:FindFirstChild("Upgrades")
	if not upgrade or not stats or not upgrades or buying[player] then return false, "Please wait..." end
	buying[player] = true
	local level = upgrades[id]
	local ok, msg = false, ""
	if level.Value >= upgrade.Max then
		msg = "Already maxed!"
	else
		local cost = Config.GetUpgradeCost(upgrade, level.Value)
		if stats.Money.Value >= cost then
			stats.Money.Value -= cost
			level.Value += 1
			ok = true
			if id == "SpawnSpeed" then
				-- don't make them wait out the old (slower) timer
				nextSpawn[player] = math.min(nextSpawn[player] or 0, os.clock() + upgrade.Value(level.Value))
			end
		else
			msg = "Not enough money!"
		end
	end
	buying[player] = nil
	return ok, msg, level.Value
end

---------------------------------------------------------------- players
-- For a few seconds after each spawn the main loop makes sure the right scooper is in hand
-- (the character and backpack finish loading over several frames).
local equipWindow = {} -- player -> {Until = time, Next = time}

local function applySpeed(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.WalkSpeed = workspace:GetAttribute("ChaosSpeed") or upgradeValue(player, "WalkSpeed") end
end

-- characters walk through fish (only the scooper pushes them), so they never step up onto a pile
local function setCharacterGroup(part)
	if part:IsA("BasePart") and not part:FindFirstAncestorOfClass("Tool") then
		part.CollisionGroup = "Characters"
	end
end
local function onCharacterGroups(character)
	for _, d in ipairs(character:GetDescendants()) do setCharacterGroup(d) end
	character.DescendantAdded:Connect(setCharacterGroup)
end

local function checkEquip(player, now)
	local w = equipWindow[player]
	if not w or now < w.Next then return end
	if now > w.Until then equipWindow[player] = nil return end
	w.Next = now + 0.5
	local character, stats = player.Character, player:FindFirstChild("Stats")
	if not character or not stats or not character:FindFirstChildOfClass("Humanoid") then return end
	applySpeed(player)
	local held = character:FindFirstChildOfClass("Tool")
	local want = Config.GetScooperTier(stats.Collected.Value)
	if player:GetAttribute("GroupReward") then want = math.max(want, Config.Group.ScooperTier) end
	if held and held:GetAttribute("Tier") == want then return end
	giveScooper(player, true)
end

local function onPlayer(player)
	nextSpawn[player] = os.clock() + 2
	player:GetAttributeChangedSignal("GroupReward"):Connect(function() giveScooper(player, true) end)
	-- rebirthing clears their fish off the island
	task.spawn(function()
		local rebirths = player:WaitForChild("Stats"):WaitForChild("Rebirths")
		local last = rebirths.Value
		rebirths.Changed:Connect(function(v)
			if v > last then
				for fish, data in pairs(live) do
					if data.Owner == player.UserId then removeFish(fish) end
				end
				nextSpawn[player] = os.clock() + 1
			end
			last = v
		end)
	end)
	player.CharacterAdded:Connect(function(character)
		onCharacterGroups(character)
		equipWindow[player] = {Until = os.clock() + 6, Next = os.clock() + 0.5}
	end)
	if player.Character then
		onCharacterGroups(player.Character)
		equipWindow[player] = {Until = os.clock() + 6, Next = os.clock() + 0.5}
	end
	task.spawn(function()
		player:WaitForChild("Upgrades"):WaitForChild("WalkSpeed").Changed:Connect(function() applySpeed(player) end)
		-- their save just loaded: make sure they hold the scooper (and speed) it earned
		player:WaitForChild("Stats")
		equipWindow[player] = {Until = os.clock() + 6, Next = os.clock()}
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end

Players.PlayerRemoving:Connect(function(player)
	nextSpawn[player] = nil
	buying[player] = nil
	equipWindow[player] = nil
	for fish, data in pairs(live) do
		if data.Owner == player.UserId then removeFish(fish) end
	end
	ownedCount[player.UserId] = nil
end)

---------------------------------------------------------------- admin: spawn fish + boss fish
local fishByName = {}
for _, f in ipairs(Config.Fish) do fishByName[f.Name] = f end

local ServerStorage = game:GetService("ServerStorage")
local adminHook = ServerStorage:FindFirstChild("FishGameAdmin") or Instance.new("BindableFunction")
adminHook.Name = "FishGameAdmin"
adminHook.Parent = ServerStorage

local BOSS = Config.Boss
local bossActive = false

local function studify(part)
	part.Material = Enum.Material.Plastic
	for _, face in ipairs({"Top", "Bottom", "Left", "Right", "Front", "Back"}) do
		part[face .. "Surface"] = Enum.SurfaceType.Studs
	end
end

local function summonBoss()
	if bossActive then return false end
	local template = FishModels:FindFirstChild(BOSS.Model)
	if not template then return false end
	bossActive = true

	-- a giant copy of a fish, swimming in the sky in front of the island
	local boss = template:Clone()
	boss.Name = "BossFish"
	for k in pairs(boss:GetAttributes()) do boss:SetAttribute(k, nil) end
	boss:ScaleTo(BOSS.Scale)
	for _, p in ipairs(boss:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			studify(p)
		elseif p:IsA("WeldConstraint") then
			p:Destroy()
		end
	end
	local center = BOSS.Position
	-- fish models lie on their side: stand it up (top = -Z) and face it toward the island
	local upright = CFrame.Angles(math.rad(90), 0, 0)
	local face = CFrame.lookAt(center, Vector3.new(Config.Hole.Center.X, center.Y, Config.Hole.Center.Z)) -- side-on to the island
	local function place(t)
		local bob = Vector3.new(0, math.sin(t * 1.2) * 3, 0)
		boss:PivotTo(CFrame.new(bob) * face * CFrame.Angles(0, 0, math.rad(math.sin(t * 0.8) * 6)) * upright)
	end
	place(0)
	boss.Parent = workspace
	workspace:SetAttribute("BossEnds", workspace:GetServerTimeNow() + BOSS.Duration)

	local started = os.clock()
	local swim = RunService.Heartbeat:Connect(function()
		place(os.clock() - started)
	end)

	-- fish pour down for everyone while it's here
	task.spawn(function()
		local acc = 0
		while os.clock() - started < BOSS.Duration do
			local dt = task.wait(0.1)
			-- only players with room left (their max fish + the server cap still apply)
			local players = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if (ownedCount[p.UserId] or 0) < upgradeValue(p, "MaxFish") then table.insert(players, p) end
			end
			acc = math.min(acc + dt * BOSS.FishPerSecond, 5)
			while acc >= 1 and #players > 0 and liveTotal < Config.Spawning.ServerCap do
				acc -= 1
				local i = math.random(#players)
				local p = players[i]
				spawnFish(p, nil, BOSS.LuckMultiplier)
				if (ownedCount[p.UserId] or 0) >= upgradeValue(p, "MaxFish") then table.remove(players, i) end
			end
		end
		workspace:SetAttribute("BossEnds", nil)
		swim:Disconnect()
		-- sink away
		local from = boss:GetPivot()
		for i = 1, 40 do
			boss:PivotTo(from - Vector3.new(0, i * i * 0.08, 0))
			task.wait(0.03)
		end
		boss:Destroy()
		bossActive = false
	end)
	return true
end

-- chaos commands (ChaosServer)
local function flingFish(center, radius, power, swirl)
	for fish, data in pairs(live) do
		local body = fish.PrimaryPart
		if body then
			local offset = body.Position - center
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude < radius then
				release(fish, data)
				local out = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
				local side = Vector3.new(-out.Z, 0, out.X)
				body.AssemblyLinearVelocity = Vector3.new(0, power * (0.6 + math.random() * 0.6), 0)
					+ (swirl and (side * swirl - out * swirl * 0.4) or out * power * 0.4 * math.random())
				body.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
			end
		end
	end
end

adminHook.OnInvoke = function(action, target, name, count)
	if action == "Fling" then
		flingFish(target, name, count)
		return true
	elseif action == "Swirl" then
		flingFish(target, name, count, count)
		return true
	elseif action == "ApplySpeed" then
		for _, p in ipairs(Players:GetPlayers()) do applySpeed(p) end
		return true
	elseif action == "Storm" then
		-- fill the island up to the server cap with fish for everyone
		local players = Players:GetPlayers()
		local n = 0
		while #players > 0 and liveTotal < Config.Spawning.ServerCap and n < (name or 40) do
			spawnFish(players[math.random(#players)], nil, 3, true)
			n += 1
		end
		return true
	elseif action == "Boss" then
		return summonBoss()
	elseif action == "SpawnFish" then
		local info = fishByName[name]
		if not info or not target then return false end
		for _ = 1, math.clamp(math.floor(count or 1), 1, 50) do
			spawnFish(target, info, 1, true)
		end
		return true
	end
	return false
end

---------------------------------------------------------------- main loop
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.05 then return end
	acc = 0
	local now = os.clock()

	for fish, data in pairs(live) do
		local root = fish.Parent and fish.PrimaryPart
		if not root then
			removeFish(fish)
		else
			local pos = root.Position
			if not data.Settled and now - (data.ReleasedAt or 0) > 1 then
				-- landed on the floor? lock it down (not right after being let go over the hole)
				-- (if that spot is inside a scooper wall, it's slid out to the nearest clear side first)
				local reach = math.max(root.Size.X, root.Size.Y, root.Size.Z) / 2
				if pos.Y < FLOOR_Y + reach + 0.4 and pos.Y > FLOOR_Y - 0.5
					and math.abs(root.AssemblyLinearVelocity.Y) < 8 and groundBelow(root) then
					local spot = clearOfScoopers(flatSpot(root), root)
					if spot then settle(fish, data, spot) end
				end
			elseif data.Settled and now >= data.NextGroundCheck then
				-- pushed out over the hole / off an edge: let it fall
				data.NextGroundCheck = now + 0.15
				if not groundBelow(root) then release(fish, data) end
			end
			if inHole(pos) then
				collect(fish, pos)
			elseif pos.Y < hole.Center.Y - 60 or now - (data.TouchTime or data.Born) > Config.Spawning.Lifetime then
				removeFish(fish) -- fell off the world or sat around too long
			end
		end
	end
	payOut()

	local sp = Config.Spawning
	for _, player in ipairs(Players:GetPlayers()) do
		checkEquip(player, now)
		local due = nextSpawn[player]
		if due then
			local maxFish = upgradeValue(player, "MaxFish")
			-- at high spawn speeds several fish can be due in one tick
			local spawned = 0
			while now >= due and spawned < 6 do
				local owned = ownedCount[player.UserId] or 0
				local interval = upgradeValue(player, "SpawnSpeed") / Config.EventBoost("Spawn")
				if owned < maxFish * sp.RefillBelow then interval /= sp.RefillSpeed end
				due = math.max(due + interval, now - 1) -- don't build up a huge backlog
				if owned < maxFish and liveTotal < sp.ServerCap then
					spawnFish(player)
					spawned += 1
				else
					due = math.max(due, now) -- full: check again next tick
					break
				end
			end
			nextSpawn[player] = due
		end
	end
end)
