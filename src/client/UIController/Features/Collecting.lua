-- What happens when fish drop into the hole: bursts and "+$" text in the world for everyone,
-- and for the collector coins flying into the money counter, a combo counter and rare-catch popups.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Sound = require(Core.Sound)
local Toasts = require(Core.Toasts)
local Screen = require(Core.Screen)
local Rarity = require(Core.Rarity)
local VFX = require(Core.VFX)
local WorldFX = require(Core.WorldFX)
local Celebration = require(Core.Celebration)

local player = Context.Player
local tween, seq, BACK, QUAD, IN, WHITE = Util.tween, Util.seq, Util.BACK, Util.QUAD, Util.IN, Util.WHITE
local LeftHUD, FX = Context.Gui.LeftHUD, Context.Gui.FX
local comboLabel = Context.Gui.ComboHolder.Combo
local GOLD_DEBRIS = Color3.fromRGB(255, 220, 60)
local MONEY_GREEN = Color3.fromRGB(150, 255, 110)

local Collecting = {}

local FishModels
local combo, lastCollect, comboId = 0, 0, 0

-- coins burst out of the hole on screen, then fly into the money counter one by one
local function flyCoins(from, n)
	local icon = LeftHUD.MoneyCounter.Icon
	local uiScale = Screen.Scale
	for i = 1, n do
		task.delay((i - 1) * 0.05, function()
			local c = Instance.new("ImageLabel")
			c.BackgroundTransparency = 1
			c.Image = icon.Image
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			local size = (34 + math.random() * 14) * uiScale
			c.Size = UDim2.fromOffset(size * 0.3, size * 0.3)
			c.Position = UDim2.fromOffset(from.X, from.Y)
			c.Rotation = math.random(-40, 40)
			c.ZIndex = 6
			c.Parent = FX
			local a = math.random() * math.pi * 2
			local r = (50 + math.random() * 60) * uiScale
			local mid = from + Vector2.new(math.cos(a) * r, math.sin(a) * r - 30 * uiScale)
			tween(c, 0.28, {Position = UDim2.fromOffset(mid.X, mid.Y), Size = UDim2.fromOffset(size, size), Rotation = c.Rotation + math.random(-60, 60)}, BACK)
			task.delay(0.3, function()
				local target = Util.centerOf(icon)
				tween(c, 0.42, {Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(size * 0.6, size * 0.6), Rotation = 0}, QUAD, IN)
				task.delay(0.42, function()
					c:Destroy()
					Sound.play("Coin", 1.1 + i * 0.04)
					icon.Rotation = -26
					tween(icon, 0.3, {Rotation = -8}, BACK)
					icon.Size = UDim2.fromOffset(70, 70)
					tween(icon, 0.25, {Size = UDim2.fromOffset(58, 58)}, BACK)
				end)
			end)
		end)
	end
end

local function showCombo()
	comboId += 1
	local id = comboId
	comboLabel.Text = "x" .. combo .. " COMBO!"
	local hue = (combo * 0.07) % 1 -- colour shifts as the combo grows
	comboLabel.ComboGradient.Color = seq({Color3.fromHSV(hue, 0.35, 1), Color3.fromHSV((hue + 0.08) % 1, 0.85, 1)})
	comboLabel.Pop.Scale = 1.45 + math.min(combo, 20) * 0.02
	comboLabel.Rotation = math.random(-8, 8)
	tween(comboLabel.Pop, 0.4, {Scale = 1 + math.min(combo, 20) * 0.015}, BACK)
	tween(comboLabel, 0.4, {Rotation = 0}, BACK)
	task.delay(2.6, function()
		if id == comboId then tween(comboLabel.Pop, 0.3, {Scale = 0}, BACK, IN) end
	end)
end

-- one batch = every fish this player dropped in the hole in the same moment
local function onLocalCollect(list, total, center, best)
	local now = os.clock()
	combo = now - lastCollect < 3.5 and combo + #list or #list
	lastCollect = now
	Sound.play("Collect", math.min(0.95 + math.min(combo - 1, 15) * 0.05, 1.8))
	if combo >= 2 then showCombo() end

	local camera = workspace.CurrentCamera
	local uiScale = Screen.Scale
	local sp, onScreen = camera:WorldToViewportPoint(center)
	local from = onScreen and Vector2.new(sp.X, sp.Y) or camera.ViewportSize * Vector2.new(0.5, 0.7)
	flyCoins(from, math.clamp(2 + #list, 3, 12))
	VFX.popText(from.X, from.Y - 40 * uiScale, "+$" .. Util.abbreviate(total), MONEY_GREEN, math.min(34 + #list * 1.5, 60), 90)
	if #list > 1 then
		VFX.popText(from.X, from.Y + 4 * uiScale, "x" .. #list .. " FISH", Color3.fromRGB(110, 215, 255), math.min(24 + #list, 40), 70)
	end

	-- rare fish: the big popup only the first time you ever catch each one
	local rareSound = false
	for _, f in ipairs(list) do
		local order = Rarity.Order[f.Rarity] or 1
		local color = Rarity.Color[f.Rarity] or WHITE
		if f.First and order >= 3 then
			Celebration.celebrate({
				Title = "NEW FISH!", Name = f.Name, Desc = f.Rarity:upper() .. "  +$" .. Util.abbreviate(f.Payout),
				Color = color, Model = FishModels:FindFirstChild(f.Name), ModelMode = "fish", Sound = "None", -- the popup's own fanfare is enough (no rare-catch sound on top)
			})
		elseif order >= 4 then
			rareSound = true
			if f == best then Toasts.show(f.Rarity:upper() .. " CATCH!  +$" .. Util.abbreviate(f.Payout), color) end
		end
	end
	if rareSound then Sound.play("RareCatch") end
end

-- list = {{Name, Rarity, Payout, Pos, First?}, ...} sent by the server for one payout batch
local function onFishCollected(collector, list)
	local total, center, best, bestOrder = 0, Vector3.zero, nil, 0
	for i, f in ipairs(list) do
		local order = Rarity.Order[f.Rarity] or 1
		local color = Rarity.Color[f.Rarity] or WHITE
		total += f.Payout
		center += f.Pos
		if order > bestOrder then best, bestOrder = f, order end
		-- every fish gets a little burst, Epic+ ones a big one with their own +$
		if order >= 4 then
			WorldFX.debris(f.Pos, {color, color:Lerp(WHITE, 0.5), GOLD_DEBRIS}, 8 + order * 2, 7 + order * 1.5)
			WorldFX.ringBlast(f.Pos, color, 10 + order * 3)
			WorldFX.worldText(f.Pos + Vector3.new(0, 2, 0), "+$" .. Util.abbreviate(f.Payout), color, 34 + math.min(order, 8) * 5, order >= 6)
		elseif i <= 25 then -- cap the small bursts so a huge batch doesn't spawn hundreds of parts
			WorldFX.debris(f.Pos, {color, GOLD_DEBRIS}, 3, 6)
		end
	end
	center /= #list
	Sound.playAt("Splash", center)
	if #list >= 5 then WorldFX.ringBlast(center, GOLD_DEBRIS, math.min(12 + #list, 40)) end
	WorldFX.worldText(center, "+$" .. Util.abbreviate(total), MONEY_GREEN, math.min(36 + #list * 2, 80), false)
	if collector == player then onLocalCollect(list, total, center, best) end
end

function Collecting.start()
	FishModels = ReplicatedStorage:WaitForChild("FishModels")
	Context.Remotes.FishCollected.OnClientEvent:Connect(onFishCollected)
end

return Collecting
