-- The full-screen "PURCHASED!" / "NEW FISH!" / "NEW SCOOPER!" popup with confetti.
-- Popups that arrive while one is showing are queued and shown one after another.
local RunService = game:GetService("RunService")
local Context = require(script.Parent.Context)
local Util = require(script.Parent.Util)
local Sound = require(script.Parent.Sound)
local VFX = require(script.Parent.VFX)
local Menus = require(script.Parent.Menus)
local ModelPreview = require(script.Parent.ModelPreview)

local Config, Remotes = Context.Config, Context.Remotes
local tween, seq, BACK, QUAD, IN = Util.tween, Util.seq, Util.BACK, Util.QUAD, Util.IN
local WHITE, BLACK = Util.WHITE, Util.BLACK

local Popup = Context.Gui.PurchasePopup
local pContent = Popup.Holder.Content
local pTile = pContent.Tile
local pTexts = {pContent.ItemName, pContent.Reward, pContent.Hint}
local pTextPos = {}
for i, l in ipairs(pTexts) do pTextPos[i] = l.Position end

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 200, 40), Color3.fromRGB(80, 220, 90),
	Color3.fromRGB(60, 170, 255), Color3.fromRGB(190, 80, 255), Color3.fromRGB(255, 120, 200),
}

local Celebration = {}

local celebrating, celebrationId, shownAt = false, 0, 0
local queue = {}
local celebrateConn

---------------------------------------------------------------- confetti
local function confettiPiece(fromX, dir)
	local p = Instance.new("Frame")
	p.BorderSizePixel = 0
	p.BackgroundColor3 = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
	p.Size = UDim2.fromOffset(math.random(10, 18), math.random(8, 14))
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.new(fromX, 0, 1, 20)
	p.Rotation = math.random(0, 360)
	p.ZIndex = 32
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Parent = p
	p.Parent = Popup.Confetti
	-- shoot up out of the corner, then flutter down
	local apexX = fromX + dir * (0.08 + math.random() * 0.42)
	local apexY = 0.05 + math.random() * 0.45
	local up = 0.55 + math.random() * 0.3
	tween(p, up, {Position = UDim2.fromScale(apexX, apexY), Rotation = p.Rotation + math.random(-360, 360)})
	task.delay(up, function()
		local fall = 1.4 + math.random() * 0.8
		tween(p, fall, {Position = UDim2.fromScale(apexX + dir * math.random() * 0.12, 1.08), Rotation = p.Rotation + math.random(-540, 540)}, QUAD, IN)
		task.delay(fall - 0.4, function()
			tween(p, 0.4, {BackgroundTransparency = 1})
			tween(st, 0.4, {Transparency = 1})
		end)
		task.delay(fall, p.Destroy, p)
	end)
end

-- two confetti cannons, one from each bottom corner
function Celebration.confettiBurst()
	for i = 1, 36 do
		task.delay(i * 0.012, confettiPiece, 0, 1)
		task.delay(i * 0.012, confettiPiece, 1, -1)
	end
end

---------------------------------------------------------------- popup
local show

local function close()
	if not celebrating then return end
	celebrating = false
	celebrationId += 1
	tween(pContent.AnimScale, 0.25, {Scale = 0}, BACK, IN)
	tween(Popup.BurstRays, 0.3, {Size = UDim2.new()}, BACK, IN)
	tween(Popup.BurstRays2, 0.3, {Size = UDim2.new()}, BACK, IN)
	tween(Popup, 0.3, {BackgroundTransparency = 1})
	tween(Menus.Blur, 0.3, {Size = Menus.Open and 16 or 0})
	task.delay(0.32, function()
		if celebrating then return end
		if celebrateConn then celebrateConn:Disconnect(); celebrateConn = nil end
		Popup.Visible = false
		if #queue > 0 then show(table.remove(queue, 1)) end
	end)
end

show = function(item)
	celebrating = true
	celebrationId += 1
	local myId = celebrationId
	shownAt = os.clock()

	local color = item.Color or Color3.fromRGB(120, 200, 255)
	pTile.UIGradient.Color = seq({color:Lerp(WHITE, 0.3), color:Lerp(BLACK, 0.25)})
	pContent.Title.Text = item.Title or "PURCHASED!"
	pTile.Model.Visible = item.Model ~= nil
	ModelPreview.show(pTile.Model, item.Model, item.ModelMode)
	pTile.Icon.Visible = item.Image == nil and item.Model == nil
	pTile.ImageIcon.Visible = item.Image ~= nil
	pTile.ImageIcon.Image = item.Image or ""
	pTile.Icon.Text = item.Emoji or "🎁"
	pContent.ItemName.Text = item.Name
	pContent.Reward.Text = item.Desc or ""

	-- reset everything to its start state
	Popup.BackgroundTransparency = 1
	Popup.Visible = true
	pContent.AnimScale.Scale = 1
	pTile.TileScale.Scale = 0
	pTile.Rotation = -200
	pContent.Title.Pop.Scale = 0
	for i, l in ipairs(pTexts) do
		l.Position = pTextPos[i] + UDim2.fromOffset(0, 24)
		l.TextTransparency = 1
		l.UIStroke.Transparency = 1
	end
	Popup.BurstRays.Size = UDim2.new()
	Popup.BurstRays2.Size = UDim2.new()

	-- 1) darken + item spins in
	tween(Popup, 0.3, {BackgroundTransparency = 0.35})
	tween(Menus.Blur, 0.3, {Size = 22})
	Sound.play("Swipe")
	tween(pTile.TileScale, 0.55, {Scale = 1}, BACK)
	tween(pTile, 0.55, {Rotation = 0}, BACK)

	-- 2) impact: flash, rays, title, confetti cannons, sparkles
	task.delay(0.4, function()
		if myId ~= celebrationId then return end
		Sound.play(item.Sound or "Purchase")
		Sound.play("Confetti")
		Sound.play("Fanfare")
		Popup.Flash.BackgroundTransparency = 0.25
		tween(Popup.Flash, 0.5, {BackgroundTransparency = 1})
		tween(Popup.BurstRays, 0.6, {Size = UDim2.fromOffset(950, 950)}, BACK)
		tween(Popup.BurstRays2, 0.6, {Size = UDim2.fromOffset(700, 700)}, BACK)
		tween(pContent.Title.Pop, 0.5, {Scale = 1}, BACK)
		pTile.TileScale.Scale = 1.2
		tween(pTile.TileScale, 0.4, {Scale = 1}, BACK)
		Celebration.confettiBurst()
		VFX.burst(pContent, 14)
	end)

	-- 3) name, reward and hint slide up one after another
	for i, l in ipairs(pTexts) do
		task.delay(0.6 + i * 0.1, function()
			if myId ~= celebrationId then return end
			tween(l, 0.35, {Position = pTextPos[i], TextTransparency = 0}, BACK)
			tween(l.UIStroke, 0.35, {Transparency = 0})
		end)
	end

	if celebrateConn then celebrateConn:Disconnect() end
	local nextAmbient = 0
	celebrateConn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		Popup.BurstRays.Rotation = (t * 25) % 360
		Popup.BurstRays2.Rotation = -(t * 15) % 360
		pTile.TileRays.Rotation = (t * 60) % 360
		pContent.Title.TitleRainbow.Color = Util.rainbowSeq(t)
		pContent.Title.Rotation = math.sin(t * 3) * 3
		local bob = UDim2.new(0.5, 0, 0.5, math.sin(t * 3) * 6)
		pTile.Icon.Position = bob
		pTile.ImageIcon.Position = bob
		pContent.Hint.TextSize = 22 + math.sin(t * 4) * 1.5
		if t >= nextAmbient then
			nextAmbient = t + 0.1
			VFX.sparkle(pContent)
		end
	end)

	task.delay(Config.CelebrationTime or 4.5, function()
		if myId == celebrationId then close() end
	end)
end

-- item = {Title?, Name, Desc?, Color?, Image? | Emoji? | Model + ModelMode?, Sound?}
function Celebration.celebrate(item)
	if celebrating or Popup.Visible then
		table.insert(queue, item)
	else
		show(item)
	end
end

function Celebration.isActive()
	return celebrating
end

function Celebration.start()
	Popup.Visible = false
	Popup.Activated:Connect(function()
		-- short grace period so a click meant for something else doesn't skip it instantly
		if celebrating and os.clock() - shownAt > 0.8 then close() end
	end)

	local skipItem = {
		Name = "Rebirth Skipped!", Desc = "+1 Rebirth", Color = Color3.fromRGB(255, 90, 170),
		Image = Context.Gui.RightHUD.RebirthButton.Icon.Image,
	}
	Remotes.Purchased.OnClientEvent:Connect(function(id)
		local item = id == "SkipRebirth" and skipItem or nil
		if not item then
			for _, shopItem in ipairs(Config.Shop) do
				if shopItem.Id == id then item = shopItem end
			end
		end
		if item then Celebration.celebrate(item) end
	end)
end

return Celebration
