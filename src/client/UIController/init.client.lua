-- Stud UI controller: starts every UI module in order, then slides the HUD in.
--
-- Core/      shared building blocks (tweens and formatting, sounds, buttons, menus, popups, effects)
-- Features/  one module per part of the UI; each exposes start()
local Core = script.Core
local Features = script.Features

local Context = require(Core.Context)
local Util = require(Core.Util)
local VFX = require(Core.VFX)

-- shared systems first: later modules rely on these being set up
require(Core.Screen).start()
require(Core.Toasts).start()
require(Core.Menus).start()
require(Core.Celebration).start()
require(Core.ModelPreview).start()
VFX.start()

-- HUD + menus
require(Features.StatCounters).start()
require(Features.RebirthMenu).start()
require(Features.ShopUI).start()
VFX.register(Context.Gui) -- after the shop has built its sections, so their decorations animate too
require(Features.UpgradeMenu).start()
require(Features.ScooperBar).start()

-- the world
require(Features.FishEffects).start()
require(Features.Collecting).start()
require(Features.Events).start()

-- everything else
require(Features.TrailShop).start()
require(Features.Settings).start()
require(Features.Rewards).start()
require(Features.AdminPanel).start()
require(Features.Announcements).start()
require(Features.FishIndex).start()
require(Features.Promo).start()
require(Features.Tutorial).start()

---------------------------------------------------------------- intro: HUD slides in from the edges
local gui = Context.Gui
local LeftHUD, RightHUD, ScooperBar, Banner = gui.LeftHUD, gui.RightHUD, gui.ScooperBar, gui.EventBanner
local leftPos, rightPos, barPos, bannerPos = LeftHUD.Position, RightHUD.Position, ScooperBar.Position, Banner.Position
LeftHUD.Position = leftPos - UDim2.fromOffset(500, 0)
RightHUD.Position = rightPos + UDim2.fromOffset(500, 0)
ScooperBar.Position = barPos + UDim2.fromOffset(0, 300)
Banner.Position = bannerPos - UDim2.fromOffset(0, 200)
task.wait(0.3)
Util.tween(LeftHUD, 0.7, {Position = leftPos}, Util.BACK)
Util.tween(RightHUD, 0.7, {Position = rightPos}, Util.BACK)
Util.tween(ScooperBar, 0.8, {Position = barPos}, Util.BACK)
Util.tween(Banner, 0.8, {Position = bannerPos}, Util.BACK)
