-- Settings menu: music and sound effect volume sliders. Values are saved on the server
-- (see PlayerData) and come back as player attributes once the save has loaded.
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Sound = require(Core.Sound)
local Buttons = require(Core.Buttons)
local Menus = require(Core.Menus)

local Config, player = Context.Config, Context.Player
local tween, BACK = Util.tween, Util.BACK

local SettingsMenu = Context.Gui.SettingsMenu
local setWin = SettingsMenu.Window
local settingsButton = Context.Gui.RightHUD.SettingsButton

local Settings = {}

local music
local musicVolume = 1
local sliders = {} -- card -> function that redraws it from the current value

local function applyMusic()
	if music then music.Volume = Config.Music.Volume * musicVolume end
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- card needs Track (with Knob, Fill and a Hit area) and a Value label
local function bindSlider(card, get, set)
	local track = card.Track
	local knob, fill = track.Knob, track.Fill
	local dragging = false
	local lastStep = -1
	local function show(v)
		fill.Size = UDim2.fromScale(v, 1)
		knob.Position = UDim2.fromScale(v, 0.5)
		card.Value.Text = math.floor(v * 100 + 0.5) .. "%"
	end
	local function update(x)
		local v = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		set(v)
		show(v)
		local step = math.floor(v * 10 + 0.5)
		if step ~= lastStep then -- a little tick every 10%, rising in pitch
			lastStep = step
			Sound.play("Hover", 0.8 + v * 0.8)
		end
	end
	track.Hit.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging = true
			tween(knob.Bounce, 0.15, {Scale = 1.3}, BACK)
			update(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and isPress(input) then
			dragging = false
			tween(knob.Bounce, 0.3, {Scale = 1}, BACK)
			card.Value.TextSize = 40
			tween(card.Value, 0.3, {TextSize = 34}, BACK)
			Sound.play("Click")
			-- save once on release rather than on every drag step
			Context.Remotes.SaveSettings:FireServer(musicVolume, Sound.Volume)
		end
	end)
	sliders[card] = function() show(get()) end
	show(get())
end

-- the saved values arrive from the server once your data has loaded
local function loadSettings()
	musicVolume = player:GetAttribute("MusicVolume") or musicVolume
	Sound.Volume = player:GetAttribute("SfxVolume") or Sound.Volume
	applyMusic()
	for _, refresh in pairs(sliders) do refresh() end
end

function Settings.start()
	music = SoundService:WaitForChild("Music", 10)
	if music then
		music.Looped = true
		music.Volume = 0
		task.spawn(function()
			if not music.IsLoaded then music.Loaded:Wait() end -- playing before it's loaded can silently do nothing
			music:Play()
			tween(music, 3, {Volume = Config.Music.Volume * musicVolume}) -- fade in
		end)
	end

	Menus.register(SettingsMenu)
	Buttons.bind(settingsButton, function() Menus.toggle(SettingsMenu) end)
	bindSlider(setWin.Music, function() return musicVolume end, function(v) musicVolume = v; applyMusic() end)
	bindSlider(setWin.Sfx, function() return Sound.Volume end, function(v) Sound.Volume = v end)

	player:GetAttributeChangedSignal("MusicVolume"):Connect(loadSettings)
	player:GetAttributeChangedSignal("SfxVolume"):Connect(loadSettings)
	loadSettings()

	Menus.Steps[SettingsMenu] = {
		{Menus.popEntry(setWin.Music), Menus.popEntry(setWin.Music.Tile)},
		{Menus.popEntry(setWin.Sfx), Menus.popEntry(setWin.Sfx.Tile)},
	}

	local gear = settingsButton.Icon
	RunService.RenderStepped:Connect(function()
		gear.Rotation = (os.clock() * 25) % 360 -- the gear slowly turns
	end)
end

return Settings
