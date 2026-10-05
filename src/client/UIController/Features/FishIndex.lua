-- Fish index (collection book): every fish in the game, black silhouettes until you've caught one.
-- Each discovery adds a permanent money bonus.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Buttons = require(Core.Buttons)
local Toasts = require(Core.Toasts)
local Menus = require(Core.Menus)
local ModelPreview = require(Core.ModelPreview)

local Config = Context.Config
local tween, BACK = Util.tween, Util.BACK

local IndexMenu = Context.Gui.IndexMenu
local iw = IndexMenu.Window
local indexButton = Context.Gui.LeftHUD.IndexButton

local FishIndex = {}

local cards = {} -- fish name -> card
local shownState = {} -- fish name -> "found" / "hidden" (so previews are only rebuilt when that changes)
local discovered, FishModels

local function update()
	local names, count = {}, 0
	for _, v in ipairs(discovered:GetChildren()) do
		if cards[v.Name] then names[v.Name] = true count += 1 end
	end
	for _, f in ipairs(Config.Fish) do
		local card, found = cards[f.Name], names[f.Name]
		card.FishName.Text = found and f.Name:upper() or "???"
		local state = found and "found" or "hidden"
		if shownState[f.Name] ~= state then
			shownState[f.Name] = state
			ModelPreview.show(card.Preview, FishModels:FindFirstChild(f.Name), "fish")
		end
		-- undiscovered fish are black silhouettes
		card.Preview.ImageColor3 = found and Util.WHITE or Util.BLACK
		card.Preview.ImageTransparency = found and 0 or 0.25
	end
	local mult = Config.GetIndexMultiplier(names)
	iw.SubHeader.Text.Text = count .. "/" .. #Config.Fish .. " discovered  |  Index bonus x" .. Util.trim(string.format("%.2f", mult))
end

local function onDiscovered(v)
	update()
	-- new entry: the index button hops
	indexButton.Bounce.Scale = 1.4
	tween(indexButton.Bounce, 0.5, {Scale = 1}, BACK)
	indexButton.Dot.Visible = true
	for _, info in ipairs(Config.Fish) do
		if info.Name == v.Name then
			Toasts.show("INDEX: +" .. math.floor((Config.IndexBonus[info.Rarity] or 0) * 100 + 0.5) .. "% MONEY FOREVER!", Util.GREEN)
		end
	end
end

function FishIndex.start()
	Menus.register(IndexMenu)
	Buttons.bind(indexButton, function() Menus.toggle(IndexMenu) end)
	indexButton.Activated:Connect(function() indexButton.Dot.Visible = false end)

	discovered = Context.Player:WaitForChild("Discovered")
	FishModels = ReplicatedStorage:WaitForChild("FishModels")
	for _, f in ipairs(Config.Fish) do cards[f.Name] = iw.Grid[f.Name] end
	update()
	discovered.ChildAdded:Connect(onDiscovered)

	-- only the top 3 rows of 4 animate in; the rest are below the fold anyway
	local steps, row = {}, {}
	for i, f in ipairs(Config.Fish) do
		table.insert(row, Menus.popEntry(cards[f.Name]))
		if #row == 4 or i == #Config.Fish then table.insert(steps, row) row = {} end
		if #steps >= 3 then break end
	end
	Menus.Steps[IndexMenu] = steps

	RunService.RenderStepped:Connect(function()
		indexButton.Icon.Rotation = math.sin(os.clock() * 2) * 6
	end)
end

return FishIndex
