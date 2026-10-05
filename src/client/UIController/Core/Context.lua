-- Shared references every UI module needs: the local player, their stat values, the ScreenGui,
-- the shared Config module and the remotes folder.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("StudUI")
local stats = player:WaitForChild("Stats")

return {
	Player = player,
	Gui = script.Parent.Parent.Parent, -- Context -> Core -> UIController (LocalScript) -> ScreenGui
	Config = require(Shared:WaitForChild("Config")),
	Remotes = Shared:WaitForChild("Remotes"),
	Money = stats:WaitForChild("Money"),
	Luck = stats:WaitForChild("Luck"),
	Rebirths = stats:WaitForChild("Rebirths"),
	Collected = stats:WaitForChild("Collected"),
	Multiplier = stats:WaitForChild("Multiplier"),
	Upgrades = player:WaitForChild("Upgrades"),
}
