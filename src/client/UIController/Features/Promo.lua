-- Shop offers that slide in from the side every few minutes, only when nothing else is going on.
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Sound = require(Core.Sound)
local Buttons = require(Core.Buttons)
local Menus = require(Core.Menus)
local VFX = require(Core.VFX)
local Celebration = require(Core.Celebration)

local Config, player = Context.Config, Context.Player
local tween, BACK, IN, ROBUX = Util.tween, Util.BACK, Util.IN, Util.ROBUX

local promo = Context.Gui.Promo
local card = promo.Card
local SHOWN = promo.Position
local HIDDEN = SHOWN + UDim2.fromOffset(700, 0)

local Promo = {}

local current, token = nil, 0
local prices = {} -- item id -> live Robux price, cached after the first lookup

local function hide()
	token += 1
	if not promo.Visible then return end
	local tw = tween(promo, 0.35, {Position = HIDDEN}, BACK, IN)
	tw.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then promo.Visible = false end
	end)
end

-- everything that's set up and that they don't already own
local function offers()
	local list = {}
	for _, item in ipairs(Config.Shop) do
		if item.AssetId ~= 0 and not (item.Kind == "GamePass" and player:GetAttribute("Owns_" .. item.Id)) then
			table.insert(list, item)
		end
	end
	return list
end

local function show()
	local list = offers()
	if #list == 0 then return end
	local item = list[math.random(#list)]
	if #list > 1 then
		while item == current do item = list[math.random(#list)] end -- never the same one twice in a row
	end
	current = item
	token += 1
	local my = token
	local color = item.Color or Color3.fromRGB(120, 200, 255)
	card.Tile.UIGradient.Color = Util.seq({color:Lerp(Util.WHITE, 0.3), color:Lerp(Util.BLACK, 0.25)})
	card.Tile.Icon.Image = item.Image or ""
	card.UpgradeName.Text = item.Name
	card.Desc.Text = item.Desc or ""
	card.Buy:FindFirstChild("Text").Text = ROBUX .. (prices[item.Id] or item.Price or "?")
	if not prices[item.Id] then
		task.spawn(function()
			local infoType = item.Kind == "GamePass" and Enum.InfoType.GamePass or Enum.InfoType.Product
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.AssetId, infoType)
			if ok and info.PriceInRobux then
				prices[item.Id] = info.PriceInRobux
				if current == item then card.Buy:FindFirstChild("Text").Text = ROBUX .. info.PriceInRobux end
			end
		end)
	end
	-- slide in from the right with a little flash + sparkles
	promo.Position = HIDDEN
	promo.Visible = true
	tween(promo, 0.55, {Position = SHOWN}, BACK)
	card.Flash.BackgroundTransparency = 0.2
	tween(card.Flash, 0.6, {BackgroundTransparency = 1})
	card.Tile.Icon.Bounce.Scale = 0
	task.delay(0.25, function() tween(card.Tile.Icon.Bounce, 0.5, {Scale = 1}, BACK) VFX.burst(card, 10) end)
	Sound.play("Swipe", 1.1)
	task.delay(Config.Promo.Stay, function()
		if token == my then hide() end
	end)
end

function Promo.start()
	Buttons.bind(promo.Close, hide)
	Buttons.bind(card.Buy, function()
		local item = current
		if not item then return end
		if item.Kind == "GamePass" then
			MarketplaceService:PromptGamePassPurchase(player, item.AssetId)
		else
			MarketplaceService:PromptProductPurchase(player, item.AssetId)
		end
		hide()
	end)

	task.spawn(function()
		task.wait(Config.Promo.First)
		while true do
			-- wait for a quiet moment (no menu open, no big popup)
			while Menus.Open or Celebration.isActive() do task.wait(2) end
			show()
			task.wait(Config.Promo.Every + math.random(-30, 30))
		end
	end)

	-- the offer gently wobbles so it catches your eye
	RunService.RenderStepped:Connect(function()
		if promo.Visible then
			local t = os.clock()
			promo.Ribbon.Rotation = -4 + math.sin(t * 4) * 3
			card.Tile.Icon.Rotation = math.sin(t * 2.5) * 10
		end
	end)
end

return Promo
