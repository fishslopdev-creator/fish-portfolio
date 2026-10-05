-- Robux shop: builds a section per item kind (game passes, products ...) from Config.Shop,
-- with live prices, "OWNED" state for game passes and bobbing item icons.
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Buttons = require(Core.Buttons)
local Toasts = require(Core.Toasts)
local Menus = require(Core.Menus)

local Config, player = Context.Config, Context.Player
local seq, WHITE, BLACK, ROBUX = Util.seq, Util.WHITE, Util.BLACK, Util.ROBUX

local ShopMenu = Context.Gui.ShopMenu
local shopBtn = Context.Gui.RightHUD.ShopButton
local list = ShopMenu.Window.Items
local templates = ShopMenu.Templates

local ShopUI = {}

local buttonSeqs = {}
for i, pair in ipairs(Config.ButtonColors) do buttonSeqs[i] = seq(pair) end
local OWNED_SEQ = Util.BUY_OFF
local slotIcons = {} -- {icon, index} for the bobbing animation

local function buildSlot(item, index, parent)
	local slot = templates.Slot:Clone()
	slot.Name = item.Id
	slot.LayoutOrder = index
	slot.Visible = true
	local tile = slot.Tile
	local color = item.Color or Color3.fromRGB(120, 200, 255)
	tile.UIGradient.Color = seq({color:Lerp(WHITE, 0.3), color:Lerp(BLACK, 0.25)})
	tile.ItemName.Text = item.Name
	if item.Image then
		tile.Icon.Visible = false
		tile.ImageIcon.Visible = true
		tile.ImageIcon.Image = item.Image
		table.insert(slotIcons, {tile.ImageIcon, index})
	else
		tile.Icon.Text = item.Emoji or "?"
		table.insert(slotIcons, {tile.Icon, index})
	end
	slot.Tag.Visible = item.Tag ~= nil
	slot.Tag.Text = item.Tag or ""
	slot.Desc.Text = item.Desc or ""
	local buy = slot.Buy
	buy.UIGradient.Color = buttonSeqs[(index - 1) % #buttonSeqs + 1]
	buy.Price.Text = ROBUX .. (item.Price or "?")
	slot.Parent = parent

	-- the price in Config is only a placeholder until the real one loads
	if item.AssetId ~= 0 then
		task.spawn(function()
			local infoType = item.Kind == "GamePass" and Enum.InfoType.GamePass or Enum.InfoType.Product
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.AssetId, infoType)
			if ok and info.PriceInRobux and not player:GetAttribute("Owns_" .. item.Id) then
				buy.Price.Text = ROBUX .. info.PriceInRobux
			end
		end)
	end

	local function updateOwned()
		if item.Kind == "GamePass" and player:GetAttribute("Owns_" .. item.Id) then
			buy.Price.Text = "OWNED"
			buy.UIGradient.Color = OWNED_SEQ
		end
	end
	player:GetAttributeChangedSignal("Owns_" .. item.Id):Connect(updateOwned)
	updateOwned()

	Buttons.bind(buy, function()
		if item.AssetId == 0 then
			Util.shake(buy)
			Toasts.show("Set an AssetId for " .. item.Name .. " in Config!", Util.RED)
		elseif item.Kind == "GamePass" then
			if not player:GetAttribute("Owns_" .. item.Id) then
				MarketplaceService:PromptGamePassPurchase(player, item.AssetId)
			end
		else
			MarketplaceService:PromptProductPurchase(player, item.AssetId)
		end
	end)
end

local function buildSections()
	local index = 0
	for si, section in ipairs(Config.ShopSections) do
		local items = {}
		for _, item in ipairs(Config.Shop) do
			if item.Kind == section.Kind then table.insert(items, item) end
		end
		if #items > 0 then
			local s = templates.Section:Clone()
			s.Name = "Section" .. si
			s.LayoutOrder = si
			s.Visible = true
			s.PanelGradient.Color = seq(section.Colors)
			s.Tagline.Text = section.Tagline or ""
			s.Title.Text = section.Title or ""
			if section.ArtImage then
				s.Art.Visible = false
				s.ArtImage.Visible = true
				s.ArtImage.Image = section.ArtImage
			else
				s.Art.Text = section.Art or ""
			end
			-- 3 slots per row, 228px tall with 12px gaps
			local rows = math.ceil(#items / 3)
			s.Size = UDim2.new(1, -18, 0, rows * 228 + (rows - 1) * 12 + 26)
			for _, item in ipairs(items) do
				index += 1
				buildSlot(item, index, s.Tiles)
			end
			s.Parent = list
		end
	end
end

local function framesInOrder(parent)
	local frames = {}
	for _, f in ipairs(parent:GetChildren()) do
		if f:IsA("Frame") then table.insert(frames, f) end
	end
	table.sort(frames, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	return frames
end

-- each section header animates in, then each of its slots
local function buildIntro()
	local steps = {}
	for _, s in ipairs(framesInOrder(list)) do
		local art = s.Art.Visible and s.Art or s.ArtImage
		table.insert(steps, {Menus.slideEntry(s.Tagline), Menus.slideEntry(s.Title), Menus.popEntry(art)})
		for _, slot in ipairs(framesInOrder(s.Tiles)) do
			table.insert(steps, {Menus.popEntry(slot.Tile), Menus.slideEntry(slot.Tag), Menus.popEntry(slot.Buy), Menus.slideEntry(slot.Desc)})
		end
	end
	Menus.Steps[ShopMenu] = steps
end

function ShopUI.start()
	Menus.register(ShopMenu)
	Buttons.bind(shopBtn, function()
		shopBtn.NewBadge.Visible = false
		Menus.toggle(ShopMenu)
	end)
	buildSections()
	buildIntro()

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		shopBtn.Icon.Rotation = math.sin(t * 2.2) * 6
		shopBtn.NewBadge.Rotation = -14 + math.sin(t * 5) * 5
		if Menus.Open and ShopMenu.Visible then
			for _, ic in ipairs(slotIcons) do
				ic[1].Position = UDim2.new(0.5, 0, 0, 56 + math.sin(t * 3 + ic[2]) * 4)
				ic[1].Rotation = math.sin(t * 2 + ic[2]) * 6
			end
		end
	end)
end

return ShopUI
