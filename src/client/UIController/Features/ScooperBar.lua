-- Progress bar at the bottom of the screen towards the next scooper, with a spinning 3D preview
-- of it, and the "NEW SCOOPER!" popup when one unlocks.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Menus = require(Core.Menus)
local ModelPreview = require(Core.ModelPreview)
local Celebration = require(Core.Celebration)

local Config, Collected = Context.Config, Context.Collected
local tween, BACK = Util.tween, Util.BACK

local Bar = Context.Gui.ScooperBar
local barPreview, barTrack = Bar.Preview, Bar.Track

local ScooperBar = {}

local scooperTools = {} -- tier -> Tool
local shownTool

local function toolColor(tool)
	local part = tool:FindFirstChild("BackBar") or tool:FindFirstChild("Handle")
	return part and part.Color or Color3.fromRGB(120, 200, 255)
end

local function update(animate)
	local c = Collected.Value
	local unlocks = Config.ScooperUnlocks
	local tier = Config.GetScooperTier(c)
	local target, frac
	if unlocks[tier + 1] and scooperTools[tier + 1] then
		target = scooperTools[tier + 1]
		local from, to = unlocks[tier], unlocks[tier + 1]
		frac = (c - from) / (to - from)
		Bar.Title.Text = "NEXT: " .. target.Name:upper()
		barTrack.Amount.Text = Util.commas(c) .. " / " .. Util.commas(to) .. " FISH"
	else
		target = scooperTools[tier]
		frac = 1
		Bar.Title.Text = "MAX SCOOPER!"
		barTrack.Amount.Text = Util.commas(c) .. " FISH"
	end
	if target and target ~= shownTool then
		shownTool = target
		ModelPreview.show(barPreview.View, target, "spin")
	end
	local size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
	if animate then
		tween(barTrack.Fill, 0.5, {Size = size}, BACK)
		barPreview.Bounce.Scale = 1.18
		tween(barPreview.Bounce, 0.45, {Scale = 1}, BACK)
		barTrack.Amount.TextSize = 28
		tween(barTrack.Amount, 0.35, {TextSize = 22}, BACK)
	else
		barTrack.Fill.Size = size
	end
end

function ScooperBar.start()
	for _, tool in ipairs(ReplicatedStorage:WaitForChild("Scoopers"):GetChildren()) do
		if tool:GetAttribute("Tier") then scooperTools[tool:GetAttribute("Tier")] = tool end
	end
	update(false)
	Collected.Changed:Connect(function() update(true) end)

	Context.Remotes.ScooperUnlocked.OnClientEvent:Connect(function(name, tier)
		local tool = scooperTools[tier]
		Celebration.celebrate({
			Title = "NEW SCOOPER!", Name = name, Desc = "Bigger scoop, more fish!",
			Color = tool and toolColor(tool), Model = tool, ModelMode = "spin", Sound = "Unlock",
		})
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		Bar.Visible = Menus.Open == nil -- don't show through the menu windows
		barPreview.BarRays.Rotation = (t * 30) % 360
		local p = t % 2.6 -- shimmer sweep every 2.6s
		barTrack.Fill.BarGleam.Position = UDim2.new(p < 1 and -0.2 + p * 1.4 or -0.5, 0, 0.5, 0)
	end)
end

return ScooperBar
