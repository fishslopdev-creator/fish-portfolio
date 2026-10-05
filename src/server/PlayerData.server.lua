-- Player data: loads each player's save when they join, builds the Stats / Upgrades / Discovered
-- values the other scripts read and write, and saves them again (autosave, on leave, on shutdown).
--
-- Safety rules:
--   * A save that failed to load is never overwritten: the player is kicked instead of being given
--     a fresh profile that would replace their real progress on the next save.
--   * Session lock: the save remembers which server has the player open. If they rejoin a new
--     server before the old one has finished saving, the new one waits for that save first, and
--     a server that no longer owns the lock can't write over newer data.
--   * Every DataStore call is wrapped in pcall and retried with exponential backoff.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("StudUI")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")

local store = DataStoreService:GetDataStore("PlayerData_v1")

local AUTOSAVE_INTERVAL = 120 -- seconds
local MAX_ATTEMPTS = 5 -- per DataStore call
local LOCK_TIMEOUT = 600 -- a lock older than this belongs to a server that crashed, so it's ignored
local LOCK_WAITS = 4 -- how many times to wait for another server to let go before taking over

-- What a brand-new player starts with. Older saves are filled in from this when they load,
-- so adding a field here is all it takes to add new saved data.
local DEFAULT = {
	Money = 0,
	Luck = 1,
	Multiplier = 1,
	Rebirths = 0,
	Collected = 0,
	Upgrades = {}, -- upgrade id -> level
	Discovered = {}, -- fish name -> true
	Trails = {}, -- trail id -> true (owned)
	EquippedTrail = "", -- trail id, "" for none
	GroupReward = false,
	TutorialDone = false,
	MusicVolume = 1,
	SfxVolume = 1,
}

local profiles = {} -- player -> {Key, Busy, Released}

---------------------------------------------------------------- helpers
local function deepCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

-- fill in anything missing from an older save (and drop the old lock field)
local function reconcile(saved)
	local data = deepCopy(DEFAULT)
	for k, v in pairs(saved or {}) do
		if DEFAULT[k] ~= nil and type(v) == type(DEFAULT[k]) then data[k] = v end
	end
	return data
end

-- runs fn in a pcall, retrying with exponential backoff (1s, 2s, 4s, 8s)
local function retry(fn)
	local ok, result
	for attempt = 1, MAX_ATTEMPTS do
		ok, result = pcall(fn)
		if ok then return true, result end
		warn("[PlayerData] DataStore call failed (attempt " .. attempt .. "): " .. tostring(result))
		if attempt < MAX_ATTEMPTS then task.wait(2 ^ (attempt - 1)) end
	end
	return false, result
end

local function lockIsActive(lock)
	return lock ~= nil and lock.JobId ~= game.JobId and os.time() - lock.Time < LOCK_TIMEOUT
end

---------------------------------------------------------------- building the values
local function addValue(class, name, value, parent)
	local v = Instance.new(class)
	v.Name = name
	v.Value = value
	v.Parent = parent
	return v
end

local function buildValues(player, data)
	local upgrades = Instance.new("Folder")
	upgrades.Name = "Upgrades"
	for _, u in ipairs(Config.Upgrades) do
		addValue("IntValue", u.Id, math.clamp(data.Upgrades[u.Id] or 0, 0, u.Max), upgrades)
	end

	local discovered = Instance.new("Folder")
	discovered.Name = "Discovered"
	for name in pairs(data.Discovered) do
		addValue("BoolValue", name, true, discovered)
	end

	for id in pairs(data.Trails) do
		player:SetAttribute("Trail_" .. id, true)
	end
	player:SetAttribute("EquippedTrail", data.EquippedTrail ~= "" and data.EquippedTrail or nil)
	player:SetAttribute("GroupReward", data.GroupReward or nil)
	player:SetAttribute("MusicVolume", data.MusicVolume)
	player:SetAttribute("SfxVolume", data.SfxVolume)
	player:SetAttribute("TutorialDone", data.TutorialDone) -- the client waits for this to stop being nil

	local stats = Instance.new("Folder")
	stats.Name = "Stats"
	addValue("NumberValue", "Money", data.Money, stats)
	addValue("NumberValue", "Luck", data.Luck, stats)
	addValue("NumberValue", "Multiplier", data.Multiplier, stats)
	addValue("IntValue", "Rebirths", data.Rebirths, stats)
	addValue("IntValue", "Collected", data.Collected, stats)

	-- Stats goes in last: the other scripts WaitForChild("Stats") and treat it as "the save has loaded",
	-- so everything else has to be in place by then
	upgrades.Parent = player
	discovered.Parent = player
	stats.Parent = player
end

-- the reverse of buildValues: read the live values back into a table to save
local function serialize(player)
	local stats = player:FindFirstChild("Stats")
	local data = deepCopy(DEFAULT)
	for _, name in ipairs({"Money", "Luck", "Multiplier", "Rebirths", "Collected"}) do
		local v = stats and stats:FindFirstChild(name)
		if v then data[name] = v.Value end
	end
	for _, v in ipairs(player.Upgrades:GetChildren()) do data.Upgrades[v.Name] = v.Value end
	for _, v in ipairs(player.Discovered:GetChildren()) do data.Discovered[v.Name] = true end
	for _, t in ipairs(Config.Trails) do
		if player:GetAttribute("Trail_" .. t.Id) then data.Trails[t.Id] = true end
	end
	data.EquippedTrail = player:GetAttribute("EquippedTrail") or ""
	data.GroupReward = player:GetAttribute("GroupReward") == true
	data.TutorialDone = player:GetAttribute("TutorialDone") == true
	data.MusicVolume = player:GetAttribute("MusicVolume") or 1
	data.SfxVolume = player:GetAttribute("SfxVolume") or 1
	return data
end

---------------------------------------------------------------- loading
-- takes the session lock and returns the saved data (nil for a new player)
-- returns ok = false if the DataStore couldn't be reached
local function load(key)
	for attempt = 0, LOCK_WAITS do
		local lockedElsewhere = false
		local ok, saved = retry(function()
			return store:UpdateAsync(key, function(old)
				lockedElsewhere = false -- (UpdateAsync can run this more than once)
				if old and lockIsActive(old.Lock) and attempt < LOCK_WAITS then
					lockedElsewhere = true
					return nil -- returning nil cancels the write
				end
				old = old or {}
				old.Lock = {JobId = game.JobId, Time = os.time()}
				return old
			end)
		end)
		if not ok then return false end
		if not lockedElsewhere then return true, saved end
		-- another server is probably still saving them after they left: give it a moment
		task.wait(5)
	end
	return false
end

local save -- (defined below)

local function onPlayerAdded(player)
	local key = "Player_" .. player.UserId
	player:SetAttribute("JoinTime", workspace:GetServerTimeNow())

	local ok, saved = load(key)
	if not ok then
		if RunService:IsStudio() then
			-- (Studio without API access) play with default data, but never save it
			warn("[PlayerData] Couldn't load data in Studio, using defaults without saving")
			buildValues(player, reconcile(nil))
			return
		end
		player:Kick("Your data couldn't be loaded. Please rejoin in a moment, your progress is safe.")
		return
	end

	profiles[player] = {Key = key, Busy = false, Released = false}
	buildValues(player, reconcile(saved))
	-- left while we were loading: PlayerRemoving already ran without a profile, so let go of the lock here
	if not player.Parent then save(player, true) end
end

---------------------------------------------------------------- saving
-- release = true when they're leaving: the lock is cleared so the next server can load them straight away
function save(player, release)
	local profile = profiles[player]
	if not profile or profile.Released then return end
	-- one save per player at a time, so an autosave can't land after the final save and re-take the lock
	while profile.Busy do task.wait() end
	if profile.Released then return end
	profile.Busy = true
	if release then profile.Released = true end

	local data = serialize(player)
	local ok, err = retry(function()
		store:UpdateAsync(profile.Key, function(old)
			if old and lockIsActive(old.Lock) then
				return nil -- another server has taken this player over; its data is newer than ours
			end
			data.Lock = not release and {JobId = game.JobId, Time = os.time()} or nil
			return data
		end)
	end)
	if not ok then warn("[PlayerData] Couldn't save " .. player.Name .. ": " .. tostring(err)) end

	profile.Busy = false
	if release then profiles[player] = nil end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, player) end

Players.PlayerRemoving:Connect(function(player)
	save(player, true)
end)

-- autosave, so a server crash loses at most a couple of minutes
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player in pairs(profiles) do
			task.spawn(save, player, false)
		end
	end
end)

-- server shutting down: save everyone at once and wait (Roblox gives BindToClose about 30 seconds)
game:BindToClose(function()
	for player in pairs(profiles) do
		task.spawn(save, player, true)
	end
	local deadline = os.clock() + 25
	while next(profiles) and os.clock() < deadline do task.wait(0.1) end
end)

---------------------------------------------------------------- remotes that only change saved settings
Remotes.SaveSettings.OnServerEvent:Connect(function(player, music, sfx)
	-- never trust the client: check the types and clamp the range
	if typeof(music) ~= "number" or typeof(sfx) ~= "number" or music ~= music or sfx ~= sfx then return end
	player:SetAttribute("MusicVolume", math.clamp(music, 0, 1))
	player:SetAttribute("SfxVolume", math.clamp(sfx, 0, 1))
end)

Remotes.TutorialDone.OnServerEvent:Connect(function(player)
	player:SetAttribute("TutorialDone", true)
end)
