-- Rebirth menu: shows current vs. next luck and the cost, and the Robux "skip" option.
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Sound = require(Core.Sound)
local Buttons = require(Core.Buttons)
local Toasts = require(Core.Toasts)
local Menus = require(Core.Menus)
local VFX = require(Core.VFX)

local Config, Remotes = Context.Config, Context.Remotes
local Money, Luck, Rebirths = Context.Money, Context.Luck, Context.Rebirths
local tween, BACK, RED = Util.tween, Util.BACK, Util.RED

local RebirthMenu = Context.Gui.RebirthMenu
local rbBtn = Context.Gui.RightHUD.RebirthButton
local rb = RebirthMenu.Window
local panel = rb.Panel
local confirm, skip = panel.Confirm, panel.Skip

local Rebirth = {}

local CONFIRM_ON = confirm.UIGradient.Color
local CONFIRM_OFF = Util.BUY_OFF
local COST_ON = panel.CostLabel.TextColor3

local function update()
	local r = Rebirths.Value
	local cost = Config.GetRebirthCost(r)
	local canAfford = Money.Value >= cost
	rb.SubHeader.Text.Text = "You have " .. Util.commas(r) .. (r == 1 and " rebirth" or " rebirths")
	panel.CurrentTile.Value.Text = Util.formatLuck(Luck.Value)
	panel.NextTile.Value.Text = Util.formatLuck(Luck.Value * Config.Rebirth.LuckMultiplier)
	panel.CostLabel.Text = "$" .. Util.abbreviate(cost)
	panel.CostLabel.TextColor3 = canAfford and COST_ON or RED
	confirm.UIGradient.Color = canAfford and CONFIRM_ON or CONFIRM_OFF
	rbBtn.Dot.Visible = canAfford -- red dot on the HUD button when you can afford it
end

local function bindConfirm()
	local rebirthing = false
	Buttons.bind(confirm, function()
		if rebirthing then return end
		rebirthing = true
		local ok, msg = Remotes.Rebirth:InvokeServer()
		rebirthing = false
		if ok then
			Sound.play("Rebirth")
			Toasts.show("REBIRTHED! Luck x" .. Config.Rebirth.LuckMultiplier, Color3.fromRGB(120, 255, 90))
			VFX.burst(panel, 18)
			rb.Flash.BackgroundTransparency = 0.4
			tween(rb.Flash, 0.6, {BackgroundTransparency = 1})
			local v = panel.NextTile.Value
			v.TextSize = 40
			tween(v, 0.5, {TextSize = 28}, BACK)
		else
			Sound.play("Error")
			Util.shake(confirm)
			Util.shake(panel.CostLabel)
			Toasts.show(msg or "Not enough money!", RED)
		end
	end)
end

local function bindSkip()
	local skipId = Config.Rebirth.SkipProductId
	skip.Price.Text = Util.ROBUX .. Config.Rebirth.SkipPriceText
	if skipId ~= 0 then
		-- show the live price from the product, in case it was changed on the website
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, skipId, Enum.InfoType.Product)
			if ok and info.PriceInRobux then skip.Price.Text = Util.ROBUX .. info.PriceInRobux end
		end)
	end
	Buttons.bind(skip, function()
		if skipId == 0 then
			Util.shake(skip)
			Toasts.show("Set Config.Rebirth.SkipProductId first!", RED)
			return
		end
		MarketplaceService:PromptProductPurchase(Context.Player, skipId)
	end)
end

function Rebirth.start()
	Menus.register(RebirthMenu)
	Buttons.bind(rbBtn, function() Menus.toggle(RebirthMenu) end)

	Money.Changed:Connect(update)
	Luck.Changed:Connect(update)
	Rebirths.Changed:Connect(update)
	update()
	bindConfirm()
	bindSkip()

	Menus.Steps[RebirthMenu] = {
		{Menus.slideEntry(panel.Heading), Menus.slideEntry(panel.Tagline)},
		{Menus.slideEntry(panel.CurrentLabel), Menus.popEntry(panel.CurrentTile)},
		{Menus.popEntry(panel.Arrow)},
		{Menus.slideEntry(panel.NextLabel), Menus.popEntry(panel.NextTile)},
		{Menus.slideEntry(panel.CostLabel), Menus.popEntry(confirm)},
		{Menus.slideEntry(panel.SkipLabel), Menus.popEntry(skip)},
	}

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		-- HUD button idle wiggle + pulsing dot
		rbBtn.Icon.Rotation = math.sin(t * 2.2 + 1.5) * 6
		local d = 30 + math.sin(t * 7) * 4
		rbBtn.Dot.Size = UDim2.fromOffset(d, d)
		-- the arrow between current and next luck nudges sideways
		if Menus.Open and RebirthMenu.Visible then
			panel.Arrow.Position = UDim2.new(0.5, math.sin(t * 6) * 6, 0, 166)
		end
	end)
end

return Rebirth
