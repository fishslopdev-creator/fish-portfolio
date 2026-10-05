-- UI and world sound effects, with slight pitch variation and spam protection.
local SoundService = game:GetService("SoundService")
local Context = require(script.Parent.Context)
local Config = Context.Config

local Sound = {Volume = 1} -- set from the Settings menu (0..1)

local lastPlayed = {}
function Sound.play(name, speed)
	local info = Config.Sounds[name]
	if not info or info.Id == "" or Sound.Volume <= 0 then return end
	-- stop rapid repeats (e.g. sweeping the mouse across many buttons)
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.05 then return end
	lastPlayed[name] = now
	local s = Instance.new("Sound")
	s.SoundId = info.Id
	s.Volume = (info.Volume or 0.5) * Sound.Volume
	s.PlaybackSpeed = speed or 0.95 + math.random() * 0.12 -- slight pitch variation so it never sounds repetitive
	s.Parent = SoundService
	SoundService:PlayLocalSound(s)
	task.delay(4, s.Destroy, s)
end

-- a 3D sound at a point in the world
local lastPlayedAt = {}
function Sound.playAt(name, pos, speed)
	local info = Config.Sounds[name]
	if not info or info.Id == "" or Sound.Volume <= 0 then return end
	-- with fish raining down, don't stack dozens of the same sound on top of each other
	local now = os.clock()
	if lastPlayedAt[name] and now - lastPlayedAt[name] < 0.07 then return end
	lastPlayedAt[name] = now
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = info.Id
	s.Volume = (info.Volume or 0.5) * Sound.Volume
	s.PlaybackSpeed = speed or 0.92 + math.random() * 0.16
	s.RollOffMinDistance = 12
	s.RollOffMaxDistance = 160
	s.Parent = a
	s:Play()
	task.delay(4, a.Destroy, a)
end

return Sound
