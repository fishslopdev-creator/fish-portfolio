-- Stud UI controller: counters, menus, shop, animations and VFX.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gui = script.Parent
local Shared = ReplicatedStorage:WaitForChild("StudUI")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")

local stats = player:WaitForChild("Stats")
local Money = stats:WaitForChild("Money")
local Luck = stats:WaitForChild("Luck")
local Rebirths = stats:WaitForChild("Rebirths")
local Collected = stats:WaitForChild("Collected")
local Multiplier = stats:WaitForChild("Multiplier")
local Upgrades = player:WaitForChild("Upgrades")

local LeftHUD, RightHUD, Dim, Toast = gui.LeftHUD, gui.RightHUD, gui.Dim, gui.Toast
local RebirthMenu, ShopMenu, UpgradeMenu = gui.RebirthMenu, gui.ShopMenu, gui.UpgradeMenu
local TrailMenu, SettingsMenu = gui.TrailMenu, gui.SettingsMenu
local ScooperBar, FX, ComboHolder = gui.ScooperBar, gui.FX, gui.ComboHolder

local BACK, QUAD, QUART = Enum.EasingStyle.Back, Enum.EasingStyle.Quad, Enum.EasingStyle.Quart
local IN = Enum.EasingDirection.In
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local RED = Color3.fromRGB(255, 80, 80)
local ROBUX = "\u{E002} "

---------------------------------------------------------------- helpers
local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or QUAD, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function seq(colors)
	local kps = {}
	for i, c in ipairs(colors) do
		kps[i] = ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c)
	end
	return ColorSequence.new(kps)
end

local sfxVolume = 1 -- from the Settings menu (0..1)
local lastPlayed = {}
local function playSound(name, speed)
	local info = Config.Sounds[name]
	if not info or info.Id == "" or sfxVolume <= 0 then return end
	-- stop rapid repeats (e.g. sweeping the mouse across many buttons)
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.05 then return end
	lastPlayed[name] = now
	local s = Instance.new("Sound")
	s.SoundId = info.Id
	s.Volume = (info.Volume or 0.5) * sfxVolume
	s.PlaybackSpeed = speed or 0.95 + math.random() * 0.12 -- slight pitch variation so it never sounds repetitive
	s.Parent = SoundService
	SoundService:PlayLocalSound(s)
	task.delay(4, s.Destroy, s)
end

local SUFFIXES = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
local function trim(s)
	if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
	return s
end
local function abbreviate(n)
	if n < 1000 then return tostring(math.floor(n)) end
	local i = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local v = n / 10 ^ (i * 3)
	local s = v >= 100 and tostring(math.floor(v)) or v >= 10 and string.format("%.1f", v) or string.format("%.2f", v)
	return trim(s) .. SUFFIXES[i + 1]
end
local function commas(n)
	local s, k = tostring(math.floor(n)), 0
	repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
	return s
end
local function formatLuck(n)
	if n < 1000 then return trim(string.format("%.2f", n)) .. "x" end
	if n < 1e9 then return commas(n) .. "x" end
	return abbreviate(n) .. "x"
end

local function shake(obj)
	local base = obj.Position
	task.spawn(function()
		for i = 1, 6 do
			local dx = (i % 2 == 0 and 1 or -1) * (8 - i)
			obj.Position = base + UDim2.fromOffset(dx, 0)
			task.wait(0.035)
		end
		obj.Position = base
	end)
end

---------------------------------------------------------------- screen scaling
local uiScale = 1 -- current ScreenScale, for effects drawn in raw screen pixels
local function updateScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local s = math.clamp(math.min(vp.X / 1440, vp.Y / 810), 0.45, 1.6)
	uiScale = s
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("UIScale") and d.Name == "ScreenScale" then d.Scale = s end
	end
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

---------------------------------------------------------------- toast
local toastId = 0
local TOAST_HIDDEN = UDim2.new(0.5, 0, 0, -120)
local function toast(text, color)
	toastId += 1
	local id = toastId
	Toast.Text = text
	Toast.TextColor3 = color or WHITE
	Toast.Position = TOAST_HIDDEN
	tween(Toast, 0.4, {Position = UDim2.new(0.5, 0, 0, 24 + 82 * uiScale)}, BACK) -- just under the event banner
	task.delay(2.2, function()
		if id == toastId then tween(Toast, 0.3, {Position = TOAST_HIDDEN}, BACK, IN) end
	end)
end
Remotes.Notify.OnClientEvent:Connect(toast)

---------------------------------------------------------------- buttons
local function bindButton(btn, onClick)
	local scale = btn:FindFirstChild("Bounce") or Instance.new("UIScale", btn)
	local hovering = false
	btn.MouseEnter:Connect(function()
		hovering = true
		playSound("Hover")
		tween(scale, 0.18, {Scale = 1.07}, BACK)
	end)
	btn.MouseLeave:Connect(function()
		hovering = false
		tween(scale, 0.18, {Scale = 1}, BACK)
	end)
	btn.MouseButton1Down:Connect(function()
		tween(scale, 0.08, {Scale = 0.9})
	end)
	btn.MouseButton1Up:Connect(function()
		tween(scale, 0.25, {Scale = hovering and 1.07 or 1}, BACK)
	end)
	btn.Activated:Connect(function()
		playSound("Click")
		onClick()
	end)
end

---------------------------------------------------------------- counters
local function floatText(parent, text, color, x)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.Text = text
	l.TextSize = 24
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Size = UDim2.fromOffset(160, 28)
	l.Position = UDim2.fromOffset(x, 4)
	l.ZIndex = 3
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Parent = l
	l.Parent = parent
	tween(l, 0.9, {Position = UDim2.fromOffset(x + 8, -26)}, QUART)
	tween(l, 0.9, {TextTransparency = 1}, Enum.EasingStyle.Quint, IN)
	tween(st, 0.9, {Transparency = 1}, Enum.EasingStyle.Quint, IN)
	task.delay(0.95, l.Destroy, l)
end

local function bindCounter(frame, value, format, gainColor)
	local amount, icon = frame.Amount, frame.Icon
	local baseColor = amount.TextColor3
	local shown = Instance.new("NumberValue")
	shown.Value = value.Value
	amount.Text = format(shown.Value)
	shown.Changed:Connect(function(v) amount.Text = format(v) end)
	local last = value.Value
	value.Changed:Connect(function(new)
		local diff = new - last
		last = new
		tween(shown, 0.6, {Value = new}, QUART)
		amount.TextSize = 46
		tween(amount, 0.35, {TextSize = 40}, BACK)
		icon.Rotation = diff >= 0 and -24 or 12
		tween(icon, 0.45, {Rotation = -8}, BACK)
		if gainColor and diff > 0 then
			floatText(frame, "+" .. abbreviate(diff), gainColor, amount.Position.X.Offset + amount.TextBounds.X + 12)
		elseif diff < 0 then
			amount.TextColor3 = RED
			tween(amount, 0.5, {TextColor3 = baseColor})
		end
	end)
end

bindCounter(LeftHUD.MoneyCounter, Money, abbreviate, Color3.fromRGB(120, 255, 90))
bindCounter(LeftHUD.LuckCounter, Luck, formatLuck)
bindCounter(LeftHUD.CollectedCounter, Collected, abbreviate, Color3.fromRGB(110, 215, 255))

---------------------------------------------------------------- VFX
local sparkleChars = {"✦", "✧", "★"}
local function sparkle(panel)
	local s = Instance.new("TextLabel")
	s.BackgroundTransparency = 1
	s.Font = Enum.Font.FredokaOne
	s.Text = sparkleChars[math.random(#sparkleChars)]
	s.TextColor3 = math.random() < 0.6 and WHITE or Color3.fromRGB(255, 240, 140)
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Position = UDim2.fromScale(math.random(), math.random())
	s.Size = UDim2.fromOffset(40, 40)
	s.TextSize = 1
	s.Rotation = math.random(0, 90)
	s.ZIndex = 1
	s.Parent = panel
	tween(s, 0.35, {TextSize = math.random(16, 34), Rotation = s.Rotation + 90}, BACK)
	task.delay(0.4, function()
		tween(s, 0.45, {TextSize = 1, Rotation = s.Rotation + 90, TextTransparency = 1}, QUAD, IN)
	end)
	task.delay(0.9, s.Destroy, s)
end
local function burst(panel, n)
	for _ = 1, n do
		task.delay(math.random() * 0.3, sparkle, panel)
	end
end

local gleams, spinners, rainbows, flows, bars = {}, {}, {}, {}, {}
local function registerVFX(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d.Name == "Gleam" then
			table.insert(gleams, {d, math.random() * 3})
		elseif d.Name == "Rays" then
			table.insert(spinners, {d, d:GetAttribute("Speed") or 20, math.random() * 360})
		elseif d:IsA("UIGradient") and d.Name == "Rainbow" then
			table.insert(rainbows, d)
		elseif d:IsA("UIGradient") and d.Name == "PanelGradient" then
			table.insert(flows, {d, d.Rotation, math.random() * 6})
		elseif d:IsA("UIGradient") and d.Name == "BarGradient" then
			table.insert(bars, d)
		end
	end
end

local panelCache = {}
local function sparklePanelsOf(menu)
	if not panelCache[menu] then
		local found = {}
		for _, d in ipairs(menu.Window:GetDescendants()) do
			if d:GetAttribute("Sparkles") then table.insert(found, d) end
		end
		panelCache[menu] = found
	end
	return panelCache[menu]
end

---------------------------------------------------------------- staggered menu intros
-- menuSteps[menu] = ordered steps; each step is a group of elements that animate in together
local menuSteps = {}
local introToken = 0

local function popEntry(obj)
	return {pop = true, obj = obj, scale = obj:FindFirstChild("Intro") or obj:FindFirstChild("Bounce")}
end
local function slideEntry(obj)
	return {obj = obj, base = obj.Position}
end

local function prepareIntro(menu)
	for _, step in ipairs(menuSteps[menu] or {}) do
		for _, e in ipairs(step) do
			if e.pop then
				e.scale.Scale = 0
			else
				e.obj.Position = e.base + UDim2.fromOffset(0, 18)
				e.obj.TextTransparency = 1
				local st = e.obj:FindFirstChildOfClass("UIStroke")
				if st then st.Transparency = 1 end
			end
		end
	end
end

local function playIntro(menu)
	introToken += 1
	local token = introToken
	for i, step in ipairs(menuSteps[menu] or {}) do
		task.delay(0.12 + (i - 1) * 0.08, function()
			if token ~= introToken then return end
			playSound("Pop", math.min(0.85 + i * 0.07, 1.8)) -- rising pitch: pip, pip, pip...
			for j, e in ipairs(step) do
				task.delay((j - 1) * 0.04, function()
					if token ~= introToken then return end
					if e.pop then
						tween(e.scale, 0.45, {Scale = 1}, BACK)
					else
						tween(e.obj, 0.35, {Position = e.base, TextTransparency = 0}, BACK)
						local st = e.obj:FindFirstChildOfClass("UIStroke")
						if st then tween(st, 0.35, {Transparency = 0}) end
					end
				end)
			end
		end)
	end
end

---------------------------------------------------------------- menus
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = workspace.CurrentCamera

local openMenu = nil
local function setDim(on)
	if on then
		Dim.Visible = true
		tween(Dim, 0.25, {BackgroundTransparency = 0.5})
		tween(blur, 0.25, {Size = 16})
	else
		local tw = tween(Dim, 0.25, {BackgroundTransparency = 1})
		tween(blur, 0.25, {Size = 0})
		tw.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not openMenu then Dim.Visible = false end
		end)
	end
end

local function closeMenu(menu)
	if not menu.Visible then return end
	introToken += 1
	if openMenu == menu then openMenu = nil end
	tween(menu.Window.AnimScale, 0.2, {Scale = 0}, BACK, IN).Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and openMenu ~= menu then menu.Visible = false end
	end)
	if not openMenu then setDim(false) end
end

local function toggleMenu(menu)
	if openMenu == menu then closeMenu(menu) return end
	if openMenu then closeMenu(openMenu) end
	openMenu = menu
	prepareIntro(menu)
	menu.Visible = true
	playIntro(menu)
	local win = menu.Window
	win.AnimScale.Scale = 0.5
	tween(win.AnimScale, 0.45, {Scale = 1}, BACK)
	win.Flash.BackgroundTransparency = 0.3
	tween(win.Flash, 0.5, {BackgroundTransparency = 1})
	for _, panel in ipairs(sparklePanelsOf(menu)) do burst(panel, 6) end
	setDim(true)
	playSound("Open")
end

Dim.Activated:Connect(function()
	if openMenu then closeMenu(openMenu) end
end)
for _, menu in ipairs({RebirthMenu, ShopMenu, UpgradeMenu, TrailMenu, SettingsMenu}) do
	menu.Visible = false
	bindButton(menu.Window.CloseButton, function() closeMenu(menu) end)
end
bindButton(RightHUD.UpgradeButton, function() toggleMenu(UpgradeMenu) end)

bindButton(RightHUD.ShopButton, function()
	RightHUD.ShopButton.NewBadge.Visible = false
	toggleMenu(ShopMenu)
end)
bindButton(RightHUD.RebirthButton, function() toggleMenu(RebirthMenu) end)

---------------------------------------------------------------- rebirth menu
local rb = RebirthMenu.Window
local panel = rb.Panel
local confirm, skip = panel.Confirm, panel.Skip
local CONFIRM_ON = confirm.UIGradient.Color
local CONFIRM_OFF = seq({Color3.fromRGB(190, 190, 195), Color3.fromRGB(110, 110, 120)})
local COST_ON = panel.CostLabel.TextColor3

local function updateRebirth()
	local r = Rebirths.Value
	local cost = Config.GetRebirthCost(r)
	local canAfford = Money.Value >= cost
	rb.SubHeader.Text.Text = "You have " .. commas(r) .. (r == 1 and " rebirth" or " rebirths")
	panel.CurrentTile.Value.Text = formatLuck(Luck.Value)
	panel.NextTile.Value.Text = formatLuck(Luck.Value * Config.Rebirth.LuckMultiplier)
	panel.CostLabel.Text = "$" .. abbreviate(cost)
	panel.CostLabel.TextColor3 = canAfford and COST_ON or RED
	confirm.UIGradient.Color = canAfford and CONFIRM_ON or CONFIRM_OFF
	RightHUD.RebirthButton.Dot.Visible = canAfford
end
Money.Changed:Connect(updateRebirth)
Luck.Changed:Connect(updateRebirth)
Rebirths.Changed:Connect(updateRebirth)
updateRebirth()

local rebirthing = false
bindButton(confirm, function()
	if rebirthing then return end
	rebirthing = true
	local ok, msg = Remotes.Rebirth:InvokeServer()
	rebirthing = false
	if ok then
		playSound("Rebirth")
		toast("REBIRTHED! Luck x" .. Config.Rebirth.LuckMultiplier, Color3.fromRGB(120, 255, 90))
		burst(panel, 18)
		rb.Flash.BackgroundTransparency = 0.4
		tween(rb.Flash, 0.6, {BackgroundTransparency = 1})
		local v = panel.NextTile.Value
		v.TextSize = 40
		tween(v, 0.5, {TextSize = 28}, BACK)
	else
		playSound("Error")
		shake(confirm)
		shake(panel.CostLabel)
		toast(msg or "Not enough money!", RED)
	end
end)

local skipId = Config.Rebirth.SkipProductId
skip.Price.Text = ROBUX .. Config.Rebirth.SkipPriceText
if skipId ~= 0 then
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, skipId, Enum.InfoType.Product)
		if ok and info.PriceInRobux then skip.Price.Text = ROBUX .. info.PriceInRobux end
	end)
end
bindButton(skip, function()
	if skipId == 0 then
		shake(skip)
		toast("Set Config.Rebirth.SkipProductId first!", RED)
		return
	end
	MarketplaceService:PromptProductPurchase(player, skipId)
end)

---------------------------------------------------------------- exclusive shop
local list = ShopMenu.Window.Items
local templates = ShopMenu.Templates
local buttonSeqs = {}
for i, pair in ipairs(Config.ButtonColors) do buttonSeqs[i] = seq(pair) end
local OWNED_SEQ = seq({Color3.fromRGB(190, 190, 195), Color3.fromRGB(110, 110, 120)})
local slotIcons = {}

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

	bindButton(buy, function()
		if item.AssetId == 0 then
			shake(buy)
			toast("Set an AssetId for " .. item.Name .. " in Config!", RED)
		elseif item.Kind == "GamePass" then
			if not player:GetAttribute("Owns_" .. item.Id) then
				MarketplaceService:PromptGamePassPurchase(player, item.AssetId)
			end
		else
			MarketplaceService:PromptProductPurchase(player, item.AssetId)
		end
	end)
end

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
		local rows = math.ceil(#items / 3)
		s.Size = UDim2.new(1, -18, 0, rows * 228 + (rows - 1) * 12 + 26)
		for _, item in ipairs(items) do
			index += 1
			buildSlot(item, index, s.Tiles)
		end
		s.Parent = list
	end
end

registerVFX(gui)

-- intro order for each menu
menuSteps[RebirthMenu] = {
	{slideEntry(panel.Heading), slideEntry(panel.Tagline)},
	{slideEntry(panel.CurrentLabel), popEntry(panel.CurrentTile)},
	{popEntry(panel.Arrow)},
	{slideEntry(panel.NextLabel), popEntry(panel.NextTile)},
	{slideEntry(panel.CostLabel), popEntry(confirm)},
	{slideEntry(panel.SkipLabel), popEntry(skip)},
}
local shopSteps = {}
local sections = {}
for _, s in ipairs(list:GetChildren()) do
	if s:IsA("Frame") then table.insert(sections, s) end
end
table.sort(sections, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
for _, s in ipairs(sections) do
	local art = s.Art.Visible and s.Art or s.ArtImage
	table.insert(shopSteps, {slideEntry(s.Tagline), slideEntry(s.Title), popEntry(art)})
	local slots = {}
	for _, slot in ipairs(s.Tiles:GetChildren()) do
		if slot:IsA("Frame") then table.insert(slots, slot) end
	end
	table.sort(slots, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for _, slot in ipairs(slots) do
		table.insert(shopSteps, {popEntry(slot.Tile), slideEntry(slot.Tag), popEntry(slot.Buy), slideEntry(slot.Desc)})
	end
end
menuSteps[ShopMenu] = shopSteps

---------------------------------------------------------------- idle animations + VFX loop
local shopBtn, rbBtn = RightHUD.ShopButton, RightHUD.RebirthButton
local nextSparkle = 0

local function rainbowSeq(t)
	local kps = {}
	for i = 0, 4 do
		kps[i + 1] = ColorSequenceKeypoint.new(i / 4, Color3.fromHSV((t * 0.25 + i * 0.18) % 1, 0.7, 1))
	end
	return ColorSequence.new(kps)
end

local function placeSubIcons(sub, t)
	local w = sub.Text.TextBounds.X
	local pulse = 1 + math.sin(t * 4) * 0.08
	sub.LeftIcon.Position = UDim2.new(0.5, -w / 2 - 38, 0.5, 0)
	sub.RightIcon.Position = UDim2.new(0.5, w / 2 + 38, 0.5, 0)
	sub.LeftIcon.Rotation = math.sin(t * 2) * 15
	sub.RightIcon.Rotation = -math.sin(t * 2) * 15
	sub.LeftIcon.TextSize = 38 * pulse
	sub.RightIcon.TextSize = 38 * pulse
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()

	-- HUD idle
	shopBtn.Icon.Rotation = math.sin(t * 2.2) * 6
	rbBtn.Icon.Rotation = math.sin(t * 2.2 + 1.5) * 6
	shopBtn.NewBadge.Rotation = -14 + math.sin(t * 5) * 5
	local d = 30 + math.sin(t * 7) * 4
	rbBtn.Dot.Size = UDim2.fromOffset(d, d)

	if not openMenu then return end

	-- spinning light rays
	for _, s in ipairs(spinners) do
		s[1].Rotation = (s[3] + t * s[2]) % 360
	end
	-- shimmer sweeps across bars and buttons
	for _, g in ipairs(gleams) do
		local p = (t + g[2]) % 3.2
		g[1].Position = UDim2.new(p < 1 and -0.2 + p * 1.4 or -0.5, 0, 0.5, 0)
	end
	-- flowing gradients
	local rainbow = rainbowSeq(t)
	for _, g in ipairs(rainbows) do g.Color = rainbow end
	for _, f in ipairs(flows) do
		f[1].Rotation = f[2] + math.sin(t * 0.6 + f[3]) * 20
		f[1].Offset = Vector2.new(math.sin(t * 0.45 + f[3]) * 0.15, 0)
	end
	for _, b in ipairs(bars) do
		b.Offset = Vector2.new(math.sin(t * 1.1) * 0.2, 0)
	end
	-- bobbing shop icons
	if ShopMenu.Visible then
		for _, ic in ipairs(slotIcons) do
			ic[1].Position = UDim2.new(0.5, 0, 0, 56 + math.sin(t * 3 + ic[2]) * 4)
			ic[1].Rotation = math.sin(t * 2 + ic[2]) * 6
		end
	end
	-- sub header icons, arrow nudge
	placeSubIcons(openMenu.Window.SubHeader, t)
	if RebirthMenu.Visible then
		panel.Arrow.Position = UDim2.new(0.5, math.sin(t * 6) * 6, 0, 166)
	end
	-- twinkling sparkles
	if t >= nextSparkle then
		nextSparkle = t + 0.12
		local panels = sparklePanelsOf(openMenu)
		if #panels > 0 then sparkle(panels[math.random(#panels)]) end
	end
end)

---------------------------------------------------------------- purchase celebration
local Popup = gui.PurchasePopup
local pContent = Popup.Holder.Content
local pTile = pContent.Tile
local pTexts = {pContent.ItemName, pContent.Reward, pContent.Hint}
local pTextPos = {}
for i, l in ipairs(pTexts) do pTextPos[i] = l.Position end
Popup.Visible = false

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 200, 40), Color3.fromRGB(80, 220, 90),
	Color3.fromRGB(60, 170, 255), Color3.fromRGB(190, 80, 255), Color3.fromRGB(255, 120, 200),
}
local SKIP_ITEM = {Name = "Rebirth Skipped!", Desc = "+1 Rebirth", Image = RightHUD.RebirthButton.Icon.Image, Color = Color3.fromRGB(255, 90, 170)}

local celebrating, celebrationId, shownAt = false, 0, 0
local celebrationQueue = {}
local celebrateConn

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

-- 3D model previews in ViewportFrames (scooper bar, celebration popup)
local spinning = {}
local function showModelIn(vpf, source, mode)
	for _, c in ipairs(vpf:GetChildren()) do
		if not c:IsA("UIBase") then c:Destroy() end
	end
	spinning[vpf] = nil
	if not source then return end
	local model = Instance.new("Model")
	for _, d in ipairs(source:GetChildren()) do
		if d:IsA("BasePart") or d:IsA("Model") then d:Clone().Parent = model end
	end
	local cf, size = model:GetBoundingBox()
	local rel = cf:ToObjectSpace(model:GetPivot())
	local tilt = mode == "fish" and CFrame.Angles(math.rad(80), 0, 0) or CFrame.Angles(math.rad(28), 0, 0)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	local radius = (mode == "fish" and math.max(size.X, size.Z) or size.Magnitude) * 0.5
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * (mode == "fish" and 1.08 or 0.85)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, dist), Vector3.zero)
	cam.Parent = vpf
	vpf.CurrentCamera = cam
	model.Parent = vpf
	local entry = {model = model, rel = rel, tilt = tilt, mode = mode, phase = math.random() * 6}
	spinning[vpf] = entry
	model:PivotTo(tilt * rel)
end

local function confettiBurst()
	for i = 1, 36 do
		task.delay(i * 0.012, confettiPiece, 0, 1)
		task.delay(i * 0.012, confettiPiece, 1, -1)
	end
end

local showCelebration
local function closeCelebration()
	if not celebrating then return end
	celebrating = false
	celebrationId += 1
	tween(pContent.AnimScale, 0.25, {Scale = 0}, BACK, IN)
	tween(Popup.BurstRays, 0.3, {Size = UDim2.new()}, BACK, IN)
	tween(Popup.BurstRays2, 0.3, {Size = UDim2.new()}, BACK, IN)
	tween(Popup, 0.3, {BackgroundTransparency = 1})
	tween(blur, 0.3, {Size = openMenu and 16 or 0})
	task.delay(0.32, function()
		if celebrating then return end
		if celebrateConn then celebrateConn:Disconnect(); celebrateConn = nil end
		Popup.Visible = false
		if #celebrationQueue > 0 then showCelebration(table.remove(celebrationQueue, 1)) end
	end)
end

showCelebration = function(item)
	celebrating = true
	celebrationId += 1
	local myId = celebrationId
	shownAt = os.clock()

	local color = item.Color or Color3.fromRGB(120, 200, 255)
	pTile.UIGradient.Color = seq({color:Lerp(WHITE, 0.3), color:Lerp(BLACK, 0.25)})
	pContent.Title.Text = item.Title or "PURCHASED!"
	pTile.Model.Visible = item.Model ~= nil
	showModelIn(pTile.Model, item.Model, item.ModelMode)
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
	tween(blur, 0.3, {Size = 22})
	playSound("Swipe")
	tween(pTile.TileScale, 0.55, {Scale = 1}, BACK)
	tween(pTile, 0.55, {Rotation = 0}, BACK)

	-- 2) impact: flash, rays, title, confetti cannons, sparkles
	task.delay(0.4, function()
		if myId ~= celebrationId then return end
		playSound(item.Sound or "Purchase")
		playSound("Confetti")
		playSound("Fanfare")
		Popup.Flash.BackgroundTransparency = 0.25
		tween(Popup.Flash, 0.5, {BackgroundTransparency = 1})
		tween(Popup.BurstRays, 0.6, {Size = UDim2.fromOffset(950, 950)}, BACK)
		tween(Popup.BurstRays2, 0.6, {Size = UDim2.fromOffset(700, 700)}, BACK)
		tween(pContent.Title.Pop, 0.5, {Scale = 1}, BACK)
		pTile.TileScale.Scale = 1.2
		tween(pTile.TileScale, 0.4, {Scale = 1}, BACK)
		confettiBurst()
		burst(pContent, 14)
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
		pContent.Title.TitleRainbow.Color = rainbowSeq(t)
		pContent.Title.Rotation = math.sin(t * 3) * 3
		local bob = UDim2.new(0.5, 0, 0.5, math.sin(t * 3) * 6)
		pTile.Icon.Position = bob
		pTile.ImageIcon.Position = bob
		pContent.Hint.TextSize = 22 + math.sin(t * 4) * 1.5
		if t >= nextAmbient then
			nextAmbient = t + 0.1
			sparkle(pContent)
		end
	end)

	task.delay(Config.CelebrationTime or 4.5, function()
		if myId == celebrationId then closeCelebration() end
	end)
end

Popup.Activated:Connect(function()
	if celebrating and os.clock() - shownAt > 0.8 then closeCelebration() end
end)

local function celebrate(item)
	if celebrating or Popup.Visible then
		table.insert(celebrationQueue, item)
	else
		showCelebration(item)
	end
end

Remotes.Purchased.OnClientEvent:Connect(function(id)
	local item = id == "SkipRebirth" and SKIP_ITEM or nil
	if not item then
		for _, shopItem in ipairs(Config.Shop) do
			if shopItem.Id == id then item = shopItem end
		end
	end
	if item then celebrate(item) end
end)

---------------------------------------------------------------- screen-space effects
local camera = workspace.CurrentCamera

local function popText(x, y, text, color, size, rise)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextColor3 = color
	l.TextSize = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = UDim2.fromOffset(400, 80)
	l.Position = UDim2.fromOffset(x, y)
	l.ZIndex = 5
	local st = Instance.new("UIStroke")
	st.Thickness = 3.5 * uiScale
	st.Parent = l
	l.Parent = FX
	local s = (size or 30) * uiScale
	tween(l, 0.3, {TextSize = s}, BACK)
	tween(l, 1, {Position = UDim2.fromOffset(x + math.random(-20, 20), y - (rise or 70) * uiScale)}, QUART)
	task.delay(0.55, function()
		tween(l, 0.45, {TextTransparency = 1}, QUAD, IN)
		tween(st, 0.45, {Transparency = 1}, QUAD, IN)
	end)
	task.delay(1.05, l.Destroy, l)
end

local function centerOf(obj)
	return obj.AbsolutePosition + obj.AbsoluteSize / 2
end

-- camera shake for big moments
local shakeUntil, shakePower = 0, 0
RunService:BindToRenderStep("StudShake", Enum.RenderPriority.Camera.Value + 1, function()
	local left = shakeUntil - os.clock()
	if left > 0 then
		local p = shakePower * math.min(left * 3, 1)
		camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * p), math.rad((math.random() - 0.5) * p), 0)
	end
end)
local function shakeCamera(power, duration)
	shakePower = math.max(power, os.clock() < shakeUntil and shakePower or 0)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

---------------------------------------------------------------- upgrades menu
local upWin = UpgradeMenu.Window
local BUY_ON = seq({Color3.fromRGB(170, 255, 70), Color3.fromRGB(40, 185, 45)})
local BUY_OFF = seq({Color3.fromRGB(190, 190, 195), Color3.fromRGB(110, 110, 120)})
local BUY_MAX = seq({Color3.fromRGB(255, 235, 80), Color3.fromRGB(255, 160, 0)})
local upgradeCards = {}

local function updateUpgradeCard(u, animate)
	local card = upgradeCards[u.Id]
	local level = Upgrades[u.Id].Value
	local maxed = level >= u.Max
	card.Tile.Level.Text = maxed and "MAX" or "LV " .. level
	local now = u.Format(u.Value(level))
	if maxed then
		card.Stat.Text = now .. '\n<font color="#FFE65A">MAXED</font>'
	else
		card.Stat.Text = now .. '\n<font color="#9BFF6E">> ' .. u.Format(u.Value(level + 1)) .. "</font>"
	end
	local buyText = card.Buy:FindFirstChild("Text")
	if maxed then
		buyText.Text = "MAXED"
		card.Buy.UIGradient.Color = BUY_MAX
	else
		local cost = Config.GetUpgradeCost(u, level)
		buyText.Text = "$" .. abbreviate(cost)
		card.Buy.UIGradient.Color = Money.Value >= cost and BUY_ON or BUY_OFF
	end
	local fill = UDim2.fromScale(level / u.Max, 1)
	if animate then tween(card.Track.Fill, 0.45, {Size = fill}, BACK) else card.Track.Fill.Size = fill end
end

local function updateUpgradeMenu()
	local any = false
	for _, u in ipairs(Config.Upgrades) do
		updateUpgradeCard(u)
		local level = Upgrades[u.Id].Value
		if level < u.Max and Money.Value >= Config.GetUpgradeCost(u, level) then any = true end
	end
	RightHUD.UpgradeButton.Dot.Visible = any
	upWin.SubHeader.Text.Text = "Money " .. formatLuck(Multiplier.Value) .. "  |  Luck " .. formatLuck(Luck.Value)
end

local function celebrateUpgrade(u, card, step)
	local level = Upgrades[u.Id].Value
	local maxed = level >= u.Max
	playSound("LevelUp", math.min(0.9 + step * 0.05, 1.6))
	card.Flash.BackgroundTransparency = 0.35
	tween(card.Flash, 0.4, {BackgroundTransparency = 1})
	local icon = card.Tile.Icon
	icon.Bounce.Scale = 1.5
	tween(icon.Bounce, 0.45, {Scale = 1}, BACK)
	icon.Rotation = step % 2 == 0 and 18 or -18
	tween(icon, 0.45, {Rotation = 0}, BACK)
	card.Stat.TextSize = 34
	tween(card.Stat, 0.35, {TextSize = 26}, BACK)
	local lvl = card.Tile.Level
	lvl.TextSize = 30
	tween(lvl, 0.35, {TextSize = 20}, BACK)
	burst(card, maxed and 24 or 7)
	local c = centerOf(card.Buy)
	popText(c.X, c.Y - 20 * uiScale, maxed and "MAXED!" or "LEVEL UP!", maxed and Color3.fromRGB(255, 230, 90) or Color3.fromRGB(155, 255, 110), maxed and 40 or 30, 40)
	local t = centerOf(card.Tile)
	popText(t.X + 34 * uiScale, t.Y - 10 * uiScale, "+1", Color3.fromRGB(255, 232, 90), 34, 30)
	if maxed then
		playSound("Unlock")
		upWin.Flash.BackgroundTransparency = 0.5
		tween(upWin.Flash, 0.5, {BackgroundTransparency = 1})
	end
end

local holding = {}
local function tryBuy(u, card, step)
	local level = Upgrades[u.Id].Value
	if level >= u.Max then
		if step == 1 then shake(card.Buy); toast("Already maxed!", Color3.fromRGB(255, 230, 90)) end
		return false
	end
	local ok, msg = Remotes.BuyUpgrade:InvokeServer(u.Id)
	if ok then
		updateUpgradeCard(u, true)
		celebrateUpgrade(u, card, step)
	elseif step == 1 then
		playSound("Error")
		shake(card.Buy)
		local buyText = card.Buy:FindFirstChild("Text")
		buyText.TextColor3 = RED
		tween(buyText, 0.5, {TextColor3 = WHITE})
		toast(msg or "Not enough money!", RED)
	end
	return ok
end

for _, u in ipairs(Config.Upgrades) do
	local card = upWin[u.Id]
	upgradeCards[u.Id] = card
	bindButton(card.Buy, function() end) -- hover / press feel; buying happens on press so it can repeat while held
	card.Buy.MouseButton1Down:Connect(function()
		local hold = {}
		holding[u.Id] = hold
		task.spawn(function()
			local step, gap = 1, 0.4
			while holding[u.Id] == hold do
				if not tryBuy(u, card, step) then break end
				step += 1
				task.wait(gap)
				gap = math.max(gap * 0.78, 0.07) -- speeds up the longer you hold
			end
		end)
	end)
	local function release() holding[u.Id] = nil end
	card.Buy.MouseButton1Up:Connect(release)
	card.Buy.MouseLeave:Connect(release)
	Upgrades[u.Id].Changed:Connect(function() updateUpgradeMenu() end)
end
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		table.clear(holding)
	end
end)
Money.Changed:Connect(updateUpgradeMenu)
Multiplier.Changed:Connect(updateUpgradeMenu)
Luck.Changed:Connect(updateUpgradeMenu)
updateUpgradeMenu()

local upgradeSteps = {}
for _, u in ipairs(Config.Upgrades) do
	local card = upgradeCards[u.Id]
	table.insert(upgradeSteps, {popEntry(card), popEntry(card.Tile)})
end
table.insert(upgradeSteps, {slideEntry(upWin.Hint)})
menuSteps[UpgradeMenu] = upgradeSteps

---------------------------------------------------------------- scooper progress bar
local scooperTools = {}
for _, tool in ipairs(ReplicatedStorage:WaitForChild("Scoopers"):GetChildren()) do
	if tool:GetAttribute("Tier") then scooperTools[tool:GetAttribute("Tier")] = tool end
end
local FishModels = ReplicatedStorage:WaitForChild("FishModels")

local function toolColor(tool)
	local part = tool:FindFirstChild("BackBar") or tool:FindFirstChild("Handle")
	return part and part.Color or Color3.fromRGB(120, 200, 255)
end

local barPreview, barTrack = ScooperBar.Preview, ScooperBar.Track
local shownTool
local function updateScooperBar(animate)
	local c = Collected.Value
	local unlocks = Config.ScooperUnlocks
	local tier = Config.GetScooperTier(c)
	local target, frac
	if unlocks[tier + 1] and scooperTools[tier + 1] then
		target = scooperTools[tier + 1]
		local from, to = unlocks[tier], unlocks[tier + 1]
		frac = (c - from) / (to - from)
		ScooperBar.Title.Text = "NEXT: " .. target.Name:upper()
		barTrack.Amount.Text = commas(c) .. " / " .. commas(to) .. " FISH"
	else
		target = scooperTools[tier]
		frac = 1
		ScooperBar.Title.Text = "MAX SCOOPER!"
		barTrack.Amount.Text = commas(c) .. " FISH"
	end
	if target and target ~= shownTool then
		shownTool = target
		showModelIn(barPreview.View, target, "spin")
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
updateScooperBar(false)
Collected.Changed:Connect(function() updateScooperBar(true) end)

Remotes.ScooperUnlocked.OnClientEvent:Connect(function(name, tier)
	local tool = scooperTools[tier]
	celebrate({
		Title = "NEW SCOOPER!", Name = name, Desc = "Bigger scoop, more fish!",
		Color = tool and toolColor(tool), Model = tool, ModelMode = "spin", Sound = "Unlock",
	})
end)

---------------------------------------------------------------- fish in the world
local currentGrass = Color3.fromRGB(90, 200, 80) -- grass color right now (events change it)
local rarityColor, rarityOrder = {}, {}
for i, r in ipairs(Config.Rarities) do
	rarityColor[r.Name] = r.Color
	rarityOrder[r.Name] = i
end
local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientFX"
fxFolder.Parent = workspace

local SURFACES = {"TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface"}
local function studPart(size, color, cf, transparency)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.CFrame = cf
	p.Material = Enum.Material.Plastic
	for _, s in ipairs(SURFACES) do p[s] = Enum.SurfaceType.Studs end
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = transparency or 0
	p.Parent = fxFolder
	return p
end

local function randomAngles()
	return CFrame.Angles(math.random() * 6.3, math.random() * 6.3, math.random() * 6.3)
end

-- little stud cubes flying out
local function debris(pos, colors, n, power)
	for _ = 1, n do
		local s = 0.5 + math.random() * 0.6
		local p = studPart(Vector3.one * s, colors[math.random(#colors)], CFrame.new(pos) * randomAngles())
		local dir = Vector3.new(math.random() - 0.5, 0.5 + math.random() * 0.9, math.random() - 0.5).Unit
		local peak = pos + dir * power * (0.5 + math.random() * 0.7)
		local t = 0.3 + math.random() * 0.15
		tween(p, t, {CFrame = CFrame.new(peak) * randomAngles()}, QUAD)
		task.delay(t, function()
			tween(p, 0.4, {CFrame = CFrame.new(peak - Vector3.new(0, power * 0.6, 0)) * randomAngles(), Size = Vector3.one * 0.05, Transparency = 1}, QUAD, IN)
		end)
		task.delay(t + 0.42, p.Destroy, p)
	end
end

-- square stud ring that blasts outward (matches the square hole)
local function ringBlast(pos, color, size)
	local parts = {}
	for i = 0, 3 do
		local p = studPart(Vector3.new(2, 0.6, 0.6), color, CFrame.new(pos) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, 1), 0.1)
		parts[i + 1] = p
		local goal = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, size / 2)
		tween(p, 0.55, {CFrame = goal, Size = Vector3.new(size, 0.6, 0.6), Transparency = 1}, QUART)
		task.delay(0.6, p.Destroy, p)
	end
end

local lastPlayedAt = {}
local function playAt(name, pos, speed)
	local info = Config.Sounds[name]
	if not info or info.Id == "" or sfxVolume <= 0 then return end
	-- with fish raining down, don't stack dozens of the same sound on top of each other
	local now = os.clock()
	if lastPlayedAt[name] and now - lastPlayedAt[name] < 0.07 then return end
	lastPlayedAt[name] = now
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = info.Id
	s.Volume = (info.Volume or 0.5) * sfxVolume
	s.PlaybackSpeed = speed or 0.92 + math.random() * 0.16
	s.RollOffMinDistance = 12
	s.RollOffMaxDistance = 160
	s.Parent = a
	s:Play()
	task.delay(4, a.Destroy, a)
end

local function worldText(pos, text, color, size, rainbow)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(320, 90)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 300
	bb.StudsOffsetWorldSpace = Vector3.new(0, 1, 0)
	bb.Parent = a
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextColor3 = color
	l.TextSize = 1
	l.Parent = bb
	local st = Instance.new("UIStroke"); st.Thickness = 4; st.Parent = l
	if rainbow then
		local g = Instance.new("UIGradient"); g.Name = "Rainbow"; g.Color = rainbowSeq(os.clock()); g.Parent = l
	end
	tween(l, 0.35, {TextSize = size}, BACK)
	tween(bb, 1.4, {StudsOffsetWorldSpace = Vector3.new(0, 9, 0)}, QUART)
	task.delay(0.8, function()
		tween(l, 0.5, {TextTransparency = 1}, QUAD, IN)
		tween(st, 0.5, {Transparency = 1}, QUAD, IN)
	end)
	task.delay(1.4, a.Destroy, a)
end

-- name tag above Epic+ fish (anything more common would just be clutter with this many fish)
local rainbowTags = {}
local function addTag(fish, body, rarity)
	local color = rarityColor[rarity] or WHITE
	local bb = Instance.new("BillboardGui")
	bb.Name = "FishTag"
	bb.Size = UDim2.fromOffset(170, 46)
	bb.StudsOffsetWorldSpace = Vector3.new(0, body.Size.Y / 2 + 2.6, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 75
	bb.Adornee = body
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.Text = fish.Name
	name.TextColor3 = color
	local st = Instance.new("UIStroke"); st.Thickness = 2.5; st.Parent = name
	name.Parent = bb
	if (rarityOrder[rarity] or 1) >= 6 then -- Mythic and rarer
		local g = Instance.new("UIGradient"); g.Name = "TagRainbow"; g.Parent = name
		table.insert(rainbowTags, g)
	end
	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Position = UDim2.fromScale(0, 0.55)
	value.Size = UDim2.new(1, 0, 0.45, 0)
	value.Font = Enum.Font.FredokaOne
	value.TextScaled = true
	value.Text = rarity:upper() .. "  $" .. abbreviate(fish:GetAttribute("Value") or 0)
	value.TextColor3 = Color3.fromRGB(150, 255, 110)
	local st2 = Instance.new("UIStroke"); st2.Thickness = 2; st2.Parent = value
	value.Parent = bb
	bb.Parent = fish
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function onFishAdded(fish)
	local body = fish:WaitForChild("Body", 5)
	if not body then return end
	local rarity = fish:GetAttribute("Rarity") or "Common"
	local order = rarityOrder[rarity] or 1
	local color = rarityColor[rarity] or WHITE
	if order >= 4 then addTag(fish, body, rarity) end

	-- only falling fish get the drop effects (not ones already lying there when you join)
	rayParams.FilterDescendantsInstances = {fish.Parent, fxFolder, player.Character}
	local hit = workspace:Raycast(body.Position, Vector3.new(0, -200, 0), rayParams)
	if not hit or body.Position.Y - hit.Position.Y < 10 then return end
	local groundY = hit.Position.Y
	local mine = fish:GetAttribute("Owner") == player.UserId

	local shadow = studPart(Vector3.new(1, 0.2, 1), BLACK, CFrame.new(body.Position.X, groundY + 0.1, body.Position.Z), 0.9)
	local pillar, trail
	if order >= 3 then
		local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0, -body.Size.Z / 2); a0.Parent = body
		local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, 0, body.Size.Z / 2); a1.Parent = body
		trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(color)
		trail.LightEmission = 0.8
		trail.Lifetime = 0.4
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = body
	end
	if order >= 4 then
		pillar = studPart(Vector3.new(5, 90, 5), color, CFrame.new(body.Position.X, groundY + 45, body.Position.Z), 0.7)
		if mine then
			toast("INCOMING: " .. rarity:upper() .. " " .. fish.Name:upper() .. "!", color)
			playSound("Swipe", 0.8)
		end
	end

	local started = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local height = body.Position.Y - groundY
		local landed = height < body.Size.Y + 1 and body.AssemblyLinearVelocity.Y > -25
		if not body.Parent or landed or os.clock() - started > 8 then
			conn:Disconnect()
			shadow:Destroy()
			if trail then task.delay(0.4, trail.Destroy, trail) end
			if pillar then
				tween(pillar, 0.5, {Size = Vector3.new(0.2, 90, 0.2), Transparency = 1}, QUAD, IN)
				task.delay(0.5, pillar.Destroy, pillar)
			end
			if body.Parent and landed then
				local pos = Vector3.new(body.Position.X, groundY + 0.5, body.Position.Z)
				playAt("Land", pos)
				playAt("Flop", pos)
				if order >= 3 then
					debris(pos, {body.Color, body.Color:Lerp(WHITE, 0.4), currentGrass}, 6 + order, 4 + order)
				else
					debris(pos, {body.Color, currentGrass}, 2, 3)
				end
				if order >= 4 then
					ringBlast(pos, color, 16)
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if root and (root.Position - pos).Magnitude < 70 then shakeCamera(order >= 5 and 2.2 or 1.2, 0.35) end
				end
			end
			return
		end
		local near = 1 - math.clamp(height / 60, 0, 1)
		local w = 1 + near * math.max(body.Size.X, body.Size.Z)
		shadow.Size = Vector3.new(w, 0.2, w)
		shadow.CFrame = CFrame.new(body.Position.X, groundY + 0.1, body.Position.Z)
		shadow.Transparency = 0.9 - near * 0.45
	end)
end

CollectionService:GetInstanceAddedSignal("Fish"):Connect(onFishAdded)
for _, fish in ipairs(CollectionService:GetTagged("Fish")) do task.spawn(onFishAdded, fish) end

---------------------------------------------------------------- collecting
local CASH_IMAGE = LeftHUD.MoneyCounter.Icon.Image
local combo, lastCollect, comboId = 0, 0, 0
local comboLabel = ComboHolder.Combo

local function flyCoins(from, n, value)
	local icon = LeftHUD.MoneyCounter.Icon
	for i = 1, n do
		task.delay((i - 1) * 0.05, function()
			local c = Instance.new("ImageLabel")
			c.BackgroundTransparency = 1
			c.Image = CASH_IMAGE
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
				local target = centerOf(icon)
				tween(c, 0.42, {Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(size * 0.6, size * 0.6), Rotation = 0}, QUAD, IN)
				task.delay(0.42, function()
					c:Destroy()
					playSound("Coin", 1.1 + i * 0.04)
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
	local hue = (combo * 0.07) % 1
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
	playSound("Collect", math.min(0.95 + math.min(combo - 1, 15) * 0.05, 1.8))
	if combo >= 2 then showCombo() end

	local sp, onScreen = camera:WorldToViewportPoint(center)
	local from = onScreen and Vector2.new(sp.X, sp.Y) or camera.ViewportSize * Vector2.new(0.5, 0.7)
	flyCoins(from, math.clamp(2 + #list, 3, 12), total)
	popText(from.X, from.Y - 40 * uiScale, "+$" .. abbreviate(total), Color3.fromRGB(150, 255, 110), math.min(34 + #list * 1.5, 60), 90)
	if #list > 1 then
		popText(from.X, from.Y + 4 * uiScale, "x" .. #list .. " FISH", Color3.fromRGB(110, 215, 255), math.min(24 + #list, 40), 70)
	end

	-- rare fish: the big popup only the first time you ever catch each one
	local rareSound = false
	for _, f in ipairs(list) do
		local order = rarityOrder[f.Rarity] or 1
		local color = rarityColor[f.Rarity] or WHITE
		if f.First and order >= 3 then
			celebrate({
				Title = "NEW FISH!", Name = f.Name, Desc = f.Rarity:upper() .. "  +$" .. abbreviate(f.Payout),
				Color = color, Model = FishModels:FindFirstChild(f.Name), ModelMode = "fish", Sound = "None", -- the popup's own fanfare is enough (no rare-catch sound on top)
			})
		elseif order >= 4 then
			rareSound = true
			if f == best then toast(f.Rarity:upper() .. " CATCH!  +$" .. abbreviate(f.Payout), color) end
		end
	end
	if rareSound then playSound("RareCatch") end
end

Remotes.FishCollected.OnClientEvent:Connect(function(collector, list)
	local total, center, best, bestOrder = 0, Vector3.zero, nil, 0
	for i, f in ipairs(list) do
		local order = rarityOrder[f.Rarity] or 1
		local color = rarityColor[f.Rarity] or WHITE
		total += f.Payout
		center += f.Pos
		if order > bestOrder then best, bestOrder = f, order end
		-- every fish gets a little burst, Epic+ ones a big one with their own +$
		if order >= 4 then
			debris(f.Pos, {color, color:Lerp(WHITE, 0.5), Color3.fromRGB(255, 220, 60)}, 8 + order * 2, 7 + order * 1.5)
			ringBlast(f.Pos, color, 10 + order * 3)
			worldText(f.Pos + Vector3.new(0, 2, 0), "+$" .. abbreviate(f.Payout), color, 34 + math.min(order, 8) * 5, order >= 6)
		elseif i <= 25 then
			debris(f.Pos, {color, Color3.fromRGB(255, 220, 60)}, 3, 6)
		end
	end
	center /= #list
	playAt("Splash", center)
	if #list >= 5 then ringBlast(center, Color3.fromRGB(255, 220, 60), math.min(12 + #list, 40)) end
	worldText(center, "+$" .. abbreviate(total), Color3.fromRGB(150, 255, 110), math.min(36 + #list * 2, 80), false)
	if collector == player then onLocalCollect(list, total, center, best) end
end)

---------------------------------------------------------------- outlines + always-on animation
-- One Highlight on the whole fish container outlines every fish at once
-- (Roblox only draws ~31 Highlights, so one per fish wouldn't work with this many).
task.spawn(function()
	local container = workspace:WaitForChild("Fish")
	local hl = Instance.new("Highlight")
	hl.Name = "FishOutline"
	hl.FillTransparency = 1
	hl.OutlineColor = BLACK
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = container
	hl.Parent = container
end)

local upBtn = RightHUD.UpgradeButton
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	ScooperBar.Visible = openMenu == nil -- don't show through the menu windows
	upBtn.Icon.Rotation = math.sin(t * 2.2 + 3) * 6
	local d = 30 + math.sin(t * 7 + 1) * 4
	upBtn.Dot.Size = UDim2.fromOffset(d, d)

	-- scooper bar: spinning rays + shimmer
	barPreview.BarRays.Rotation = (t * 30) % 360
	local p = t % 2.6
	barTrack.Fill.BarGleam.Position = UDim2.new(p < 1 and -0.2 + p * 1.4 or -0.5, 0, 0.5, 0)

	-- rotating 3D previews
	for vpf, e in pairs(spinning) do
		if vpf.Parent and vpf.Visible then
			local yaw = e.mode == "fish" and math.sin(t * 1.6 + e.phase) * 0.5 or t * 1.4 + e.phase
			local bob = CFrame.new(0, math.sin(t * 3 + e.phase) * 0.15, 0)
			e.model:PivotTo(bob * CFrame.Angles(0, yaw, 0) * e.tilt * e.rel)
		end
	end

	-- mythic fish tags shimmer
	if #rainbowTags > 0 then
		local rainbow = rainbowSeq(t)
		for i = #rainbowTags, 1, -1 do
			local g = rainbowTags[i]
			if g:IsDescendantOf(workspace) then g.Color = rainbow else table.remove(rainbowTags, i) end
		end
	end
end)

---------------------------------------------------------------- events (seasons)
local Banner = gui.EventBanner
local Lighting = game:GetService("Lighting")
local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local baseTint = colorCorrection and colorCorrection.TintColor or WHITE
local baseClock = Lighting.ClockTime
local currentEvent, currentEventName

-- every grass square, rim and tree leaf on the islands, with its normal color
local grassParts = {}
local LEAF_REFERENCE = {Leaves = 148 / 255, PineLeaves = 125 / 255} -- leaves keep their light/dark shading
local function grassTarget(entry, event)
	local color = event and event.Grass and event.Grass[entry.role]
	if not color then return entry.base end
	local f = entry.shade
	return f and Color3.new(math.min(color.R * f, 1), math.min(color.G * f, 1), math.min(color.B * f, 1)) or color
end
local RECOLOR = {Grass = true, Rim = true, Leaves = true, PineLeaves = true}
local function addGrass(d)
	if not d:IsA("BasePart") or not RECOLOR[d.Name] then return end
	local role = d.Name == "Grass" and (d.Color.G > 0.65 and "Light" or "Dark") or d.Name
	local entry = {
		part = d,
		role = role,
		base = d.Color,
		shade = LEAF_REFERENCE[role] and d.Color.G / LEAF_REFERENCE[role],
		dist = Vector2.new(d.Position.X, d.Position.Z).Magnitude,
	}
	table.insert(grassParts, entry)
	d.Color = grassTarget(entry, currentEvent)
end
local island = workspace:WaitForChild("SkyIsland")
for _, d in ipairs(island:GetDescendants()) do addGrass(d) end
island.DescendantAdded:Connect(addGrass) -- streaming can load parts in later

local function applyEvent(event, animate)
	currentGrass = event and event.Grass and event.Grass.Light or Color3.fromRGB(90, 200, 80)
	-- grass: a white-flash ripple spreading out from the middle of the main island
	for _, e in ipairs(grassParts) do
		local target = grassTarget(e, event)
		if animate then
			task.delay(e.dist / 110, function()
				tween(e.part, 0.1, {Color = target:Lerp(WHITE, 0.6)})
				task.delay(0.1, function() tween(e.part, 0.45, {Color = target}) end)
			end)
		else
			e.part.Color = target
		end
	end
	-- lighting
	local l = event and event.Lighting or {}
	local t = animate and 3 or 0.01
	if colorCorrection then tween(colorCorrection, t, {TintColor = l.Tint or baseTint}) end
	tween(Lighting, t, {ClockTime = l.ClockTime or baseClock})
	-- banner
	if event then
		Banner.Tile.Icon.Image = event.Icon
		Banner.Tile.UIGradient.Color = seq({event.Colors[1], event.Colors[2]:Lerp(BLACK, 0.35)})
		Banner.Title.Text = event.Title
		Banner.Title.TitleGradient.Color = seq({WHITE:Lerp(event.Colors[1], 0.35), event.Colors[1]})
		Banner.Boost.Text = event.BoostText or ""
	end
end

local function announce(event)
	local y = 0.3
	local items = {}
	local function label(text, size, yOffset, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.Text = text
		l.TextColor3 = color or WHITE
		l.TextSize = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Size = UDim2.fromOffset(1400, 140)
		l.Position = UDim2.new(0.5, 0, y, yOffset * uiScale)
		l.ZIndex = 8
		local st = Instance.new("UIStroke"); st.Thickness = 5 * uiScale; st.Parent = l
		l.Parent = FX
		table.insert(items, l)
		tween(l, 0.5, {TextSize = size * uiScale}, BACK)
		return l
	end

	local rays = Instance.new("ImageLabel")
	rays.BackgroundTransparency = 1
	rays.Image = Popup.BurstRays.Image
	rays.ImageColor3 = event.Colors[1]
	rays.ImageTransparency = 0.3
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.new(0.5, 0, y, -40 * uiScale)
	rays.Size = UDim2.new()
	rays.ZIndex = 6
	rays.Parent = FX
	tween(rays, 0.6, {Size = UDim2.fromOffset(760 * uiScale, 760 * uiScale)}, BACK)

	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = event.Icon
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, 0, y, -120 * uiScale)
	icon.Size = UDim2.new()
	icon.Rotation = -180
	icon.ZIndex = 9
	icon.Parent = FX
	tween(icon, 0.6, {Size = UDim2.fromOffset(140 * uiScale, 140 * uiScale), Rotation = 0}, BACK)

	local title = label(event.Title .. "!", 100, 0)
	local g = Instance.new("UIGradient"); g.Rotation = 90; g.Color = seq({WHITE:Lerp(event.Colors[1], 0.3), event.Colors[1], event.Colors[2]}); g.Parent = title
	local minutes = math.floor((event.Duration or Config.Events.Duration) / 60 + 0.5)
	task.delay(0.25, function()
		if event.BoostText then
			label(event.BoostText .. " FOR " .. minutes .. " MINUTES!", 38, 70, Color3.fromRGB(155, 255, 110))
		end
	end)
	playSound("Swipe", 0.85)
	playSound("Unlock")

	local spin = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		rays.Rotation = (t * 30) % 360
		icon.Rotation = math.sin(t * 3) * 10
		title.Rotation = math.sin(t * 2.5) * 2
	end)

	-- after a moment everything shrinks into the banner
	task.delay(2.6, function()
		local target = centerOf(Banner.Tile)
		local dest = UDim2.fromOffset(target.X, target.Y)
		tween(rays, 0.45, {Size = UDim2.new(), Position = dest}, BACK, IN)
		tween(icon, 0.45, {Size = UDim2.fromOffset(58 * uiScale, 58 * uiScale), Position = dest}, QUAD, IN)
		for _, l in ipairs(items) do
			tween(l, 0.4, {TextSize = 1, Position = dest, TextTransparency = 1}, BACK, IN)
		end
		task.delay(0.45, function()
			spin:Disconnect()
			rays:Destroy()
			icon:Destroy()
			for _, l in ipairs(items) do l:Destroy() end
			Banner.Tile.Bounce.Scale = 1.45
			tween(Banner.Tile.Bounce, 0.5, {Scale = 1}, BACK)
			Banner.Title.TextSize = 40
			tween(Banner.Title, 0.4, {TextSize = 30}, BACK)
			burst(Banner, 10)
			playSound("Pop", 1.2)
		end)
	end)
end

local function onEventChanged(animate)
	local event, name = Config.GetEvent()
	if not event or name == currentEventName then return end
	currentEvent, currentEventName = event, name
	applyEvent(event, animate)
	if animate then announce(event) end
end
workspace:GetAttributeChangedSignal("Event"):Connect(function() onEventChanged(true) end)
onEventChanged(false)

-- falling leaves / snow / petals, rising embers (little stud parts around you)
local MAX_PARTICLES = 220
local particleCount, particleAcc = 0, 0
local GROUND_Y = Config.Hole.Center.Y

local function spawnParticle(p, center)
	local kind = p.Kind
	local size
	if kind == "Snow" then
		size = Vector3.one * (0.35 + math.random() * 0.35)
	elseif kind == "Ember" then
		size = Vector3.one * (0.25 + math.random() * 0.3)
	else
		size = Vector3.new(0.9 + math.random() * 0.6, 0.2, 0.6 + math.random() * 0.4)
	end
	local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * 75
	local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
	local from, to, time
	if kind == "Ember" then
		from = Vector3.new(x, GROUND_Y + 0.5, z)
		to = from + Vector3.new(math.random(-4, 4), 22 + math.random() * 18, math.random(-4, 4))
		time = 2.5 + math.random() * 2
	else
		local drift = kind == "Snow" and 4 or 16
		from = Vector3.new(x, center.Y + 30 + math.random() * 20, z)
		to = Vector3.new(x + (math.random() - 0.3) * drift, GROUND_Y + size.Y / 2, z + (math.random() - 0.5) * drift)
		time = (kind == "Snow" and 5 or 4) + math.random() * 2.5
	end
	local part = studPart(size, p.Colors[math.random(#p.Colors)], CFrame.new(from) * randomAngles(), kind == "Ember" and 0.15 or 0)
	particleCount += 1
	local endCF = CFrame.new(to) * (kind == "Ember" and randomAngles() or CFrame.Angles(0, math.random() * 6.3, 0))
	tween(part, time, {CFrame = endCF}, kind == "Ember" and QUAD or Enum.EasingStyle.Linear)
	local linger = kind == "Ember" and 0 or 1.2 -- leaves/snow sit on the ground for a moment
	task.delay(time + linger - 0.5, function()
		tween(part, 0.5, {Transparency = 1, Size = size * 0.3})
	end)
	task.delay(time + linger, function()
		part:Destroy()
		particleCount -= 1
	end)
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	Banner.Tile.EventRays.Rotation = (now * 25) % 360
	Banner.Tile.Icon.Rotation = math.sin(now * 2) * 8
	local left = math.max(0, math.floor((workspace:GetAttribute("EventEnds") or 0) - workspace:GetServerTimeNow()))
	Banner.Timer.Text = string.format("%d:%02d", left // 60, left % 60)
	Banner.Timer.TextColor3 = left <= 10 and (math.floor(now * 4) % 2 == 0 and RED or WHITE) or WHITE

	local p = currentEvent and currentEvent.Particle
	if not p then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local center = root and root.Position or camera.Focus.Position
	particleAcc += dt * p.Rate
	while particleAcc >= 1 do
		particleAcc -= 1
		if particleCount < MAX_PARTICLES then spawnParticle(p, center) end
	end
end)

-- (wrapped in its own function: one Luau function can only hold 200 local variables)
;(function()
---------------------------------------------------------------- fish dropping into the hole
-- Your client is usually the one simulating the fish you push, so it lets go of a fish the moment
-- it's over the hole (no waiting for the server), so fish drop straight in instead of sliding across.
do
	local hole = Config.Hole
	local down = Vector3.new(0, -3, 0)
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include
	groundParams.FilterDescendantsInstances = {workspace:WaitForChild("SkyIsland")}
	groundParams.RespectCanCollide = true
	groundParams.CollisionGroup = "PushItems" -- fish fall through the bridges
	local container = workspace:WaitForChild("Fish")
	RunService.Heartbeat:Connect(function()
		for _, fish in ipairs(container:GetChildren()) do
			local body = fish:FindFirstChild("Body")
			if body then
				local p = body.Position
				local d = math.max(math.abs(p.X - hole.Center.X), math.abs(p.Z - hole.Center.Z))
				if d > hole.Inner + 1 and d < hole.Outer - 1 and p.Y > hole.CatchY then
					local plane = body:FindFirstChildOfClass("PlaneConstraint")
					if plane and plane.Enabled and not workspace:Raycast(p, down, groundParams) then
						plane.Enabled = false
						local flat = body:FindFirstChildOfClass("AlignOrientation")
						if flat then flat.Enabled = false end
						local v = body.AssemblyLinearVelocity
						body.AssemblyLinearVelocity = Vector3.new(v.X * 0.3, -12, v.Z * 0.3)
					end
				end
			end
		end
	end)
end

---------------------------------------------------------------- trail shop
local trailWin = TrailMenu.Window
local TRAIL_EQUIP = seq({Color3.fromRGB(110, 210, 255), Color3.fromRGB(40, 120, 235)})
local trailCards = {}
local trailBusy = false

local function updateTrails()
	local equipped = player:GetAttribute("EquippedTrail")
	for _, t in ipairs(Config.Trails) do
		local card = trailCards[t.Id]
		local owned = player:GetAttribute("Trail_" .. t.Id)
		local label = card.Buy:FindFirstChild("Text")
		if equipped == t.Id then
			label.Text = "EQUIPPED"
			card.Buy.UIGradient.Color = BUY_MAX
		elseif owned then
			label.Text = "EQUIP"
			card.Buy.UIGradient.Color = TRAIL_EQUIP
		else
			label.Text = "$" .. abbreviate(t.Price)
			card.Buy.UIGradient.Color = Money.Value >= t.Price and BUY_ON or BUY_OFF
		end
		card.UIStroke.Color = equipped == t.Id and Color3.fromRGB(255, 215, 60) or BLACK
		card.UIStroke.Thickness = equipped == t.Id and 5 or 4
	end
	local current = Config.GetTrail(equipped or "")
	trailWin.SubHeader.Text.Text = "Equipped: " .. (current and current.Name or "None") .. "  |  Money " .. formatLuck(Multiplier.Value)
end

for _, t in ipairs(Config.Trails) do
	local card = trailWin[t.Id]
	trailCards[t.Id] = card
	bindButton(card.Buy, function()
		if trailBusy then return end
		local owned = player:GetAttribute("Trail_" .. t.Id)
		local equipped = player:GetAttribute("EquippedTrail") == t.Id
		local action = equipped and "Unequip" or owned and "Equip" or "Buy"
		trailBusy = true
		local ok, msg = Remotes.TrailAction:InvokeServer(action, t.Id)
		trailBusy = false
		local c = centerOf(card.Buy)
		if ok then
			card.Flash.BackgroundTransparency = 0.3
			tween(card.Flash, 0.45, {BackgroundTransparency = 1})
			card.Ribbon.Bounce.Scale = 1.25
			tween(card.Ribbon.Bounce, 0.45, {Scale = 1}, BACK)
			if action == "Buy" then
				playSound("Purchase")
				playSound("LevelUp")
				burst(card, 18)
				trailWin.Flash.BackgroundTransparency = 0.5
				tween(trailWin.Flash, 0.5, {BackgroundTransparency = 1})
				popText(c.X, c.Y - 30 * uiScale, "NEW TRAIL!", Color3.fromRGB(255, 225, 80), 36, 60)
			elseif action == "Equip" then
				playSound("Pop", 1.2)
				burst(card, 8)
				popText(c.X, c.Y - 30 * uiScale, "EQUIPPED!", Color3.fromRGB(110, 215, 255), 30, 50)
			else
				playSound("Pop", 0.8)
			end
		else
			playSound("Error")
			shake(card.Buy)
			if msg and msg ~= "" then toast(msg, RED) end
		end
	end)
	player:GetAttributeChangedSignal("Trail_" .. t.Id):Connect(updateTrails)
end
player:GetAttributeChangedSignal("EquippedTrail"):Connect(updateTrails)
Money.Changed:Connect(updateTrails)
Multiplier.Changed:Connect(updateTrails)
updateTrails()

local trailSteps = {}
for _, t in ipairs(Config.Trails) do
	local card = trailCards[t.Id]
	table.insert(trailSteps, {popEntry(card), popEntry(card.Ribbon)})
end
table.insert(trailSteps, {slideEntry(trailWin.Hint)})
menuSteps[TrailMenu] = trailSteps

-- open from the Trail Guy, close again if you walk away from him
local trailGuy
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	if prompt.Name == "TrailPrompt" then
		trailGuy = prompt.Parent
		if openMenu ~= TrailMenu then toggleMenu(TrailMenu) end
	end
end)

---------------------------------------------------------------- settings (music / sound effects volume)
local music = SoundService:WaitForChild("Music", 10)
local musicVolume = 1
local function applyMusic()
	if music then music.Volume = Config.Music.Volume * musicVolume end
end
if music then
	music.Looped = true
	music.Volume = 0
	task.spawn(function()
		if not music.IsLoaded then music.Loaded:Wait() end -- playing before it's loaded can silently do nothing
		music:Play()
		tween(music, 3, {Volume = Config.Music.Volume * musicVolume}) -- fade in
	end)
end

local setWin = SettingsMenu.Window
local sliders = {}
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
			playSound("Hover", 0.8 + v * 0.8)
		end
	end
	track.Hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			tween(knob.Bounce, 0.3, {Scale = 1}, BACK)
			card.Value.TextSize = 40
			tween(card.Value, 0.3, {TextSize = 34}, BACK)
			playSound("Click")
			Remotes.SaveSettings:FireServer(musicVolume, sfxVolume)
		end
	end)
	sliders[card] = function() show(get()) end
	show(get())
end
bindSlider(setWin.Music, function() return musicVolume end, function(v) musicVolume = v; applyMusic() end)
bindSlider(setWin.Sfx, function() return sfxVolume end, function(v) sfxVolume = v end)

-- the saved values arrive from the server once your data has loaded
local function loadSettings()
	musicVolume = player:GetAttribute("MusicVolume") or musicVolume
	sfxVolume = player:GetAttribute("SfxVolume") or sfxVolume
	applyMusic()
	for _, refresh in pairs(sliders) do refresh() end
end
player:GetAttributeChangedSignal("MusicVolume"):Connect(loadSettings)
player:GetAttributeChangedSignal("SfxVolume"):Connect(loadSettings)
loadSettings()

menuSteps[SettingsMenu] = {
	{popEntry(setWin.Music), popEntry(setWin.Music.Tile)},
	{popEntry(setWin.Sfx), popEntry(setWin.Sfx.Tile)},
}
bindButton(RightHUD.SettingsButton, function() toggleMenu(SettingsMenu) end)

---------------------------------------------------------------- trail + settings animation
local settingsIcon = RightHUD.SettingsButton.Icon
local npcSign
task.spawn(function()
	local npc = workspace:WaitForChild("Trail Guy", 30)
	local head = npc and npc:WaitForChild("Head", 30)
	local sign = head and head:WaitForChild("Sign", 30)
	npcSign = sign and sign.Title:FindFirstChild("Rainbow")
end)
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local rainbow = rainbowSeq(t)
	if npcSign then npcSign.Color = rainbow end
	-- rainbow trails on everyone wearing one
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local tr = root and root:FindFirstChild("StudTrail")
		if tr and tr:GetAttribute("Rainbow") then tr.Color = rainbow end
	end
	settingsIcon.Rotation = (t * 25) % 360 -- the gear slowly turns
	if TrailMenu.Visible then
		for id, card in pairs(trailCards) do
			local g = card.Ribbon.TrailGradient
			if g:GetAttribute("Rainbow") then g.Color = rainbow end
		end
		-- walked away from the Trail Guy? close the shop
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if openMenu == TrailMenu and trailGuy and root and (root.Position - trailGuy.Position).Magnitude > 25 then
			closeMenu(TrailMenu)
		end
	end
end)
end)()

;(function()
---------------------------------------------------------------- rewards (like + group + playtime)
local RewardsMenu, AdminMenu, AdminHUD = gui.RewardsMenu, gui.AdminMenu, gui.AdminHUD
local rewardsButton = LeftHUD.RewardsButton
local rw = RewardsMenu.Window
local GREEN = Color3.fromRGB(120, 255, 90)
local GOLD = Color3.fromRGB(255, 225, 80)
for _, menu in ipairs({RewardsMenu, AdminMenu}) do
	menu.Visible = false
	bindButton(menu.Window.CloseButton, function() closeMenu(menu) end)
end
bindButton(rewardsButton, function() toggleMenu(RewardsMenu) end)

local function textOf(btn) return btn:FindFirstChild("Text") or btn:FindFirstChild("Status") end
local function celebrateAt(btn, text, color)
	local c = centerOf(btn)
	popText(c.X, c.Y - 30 * uiScale, text, color, 36, 60)
	burst(btn.Parent, 14)
	playSound("Purchase")
	playSound("LevelUp")
	rw.Flash.BackgroundTransparency = 0.5
	tween(rw.Flash, 0.5, {BackgroundTransparency = 1})
end

-- like: Roblox can't tell us if you liked, so this one is just a thank-you
local likeCard, groupCard = rw.Like, rw.Group
local liked = false
bindButton(likeCard.Buy, function()
	if liked then return end
	liked = true
	textOf(likeCard.Buy).Text = "THANKS!"
	likeCard.Buy.UIGradient.Color = BUY_MAX
	likeCard.Tile.Icon.Bounce.Scale = 1.5
	tween(likeCard.Tile.Icon.Bounce, 0.5, {Scale = 1}, BACK)
	celebrateAt(likeCard.Buy, "THANK YOU!", GREEN)
end)

local function updateGroup()
	local claimed = player:GetAttribute("GroupReward")
	textOf(groupCard.Buy).Text = claimed and "CLAIMED" or "CLAIM"
	groupCard.Buy.UIGradient.Color = claimed and BUY_MAX or BUY_ON
end
player:GetAttributeChangedSignal("GroupReward"):Connect(updateGroup)
updateGroup()
local groupBusy = false
bindButton(groupCard.Buy, function()
	if groupBusy or player:GetAttribute("GroupReward") then return end
	groupBusy = true
	local ok, msg = Remotes.ClaimGroup:InvokeServer()
	groupBusy = false
	if ok then
		groupCard.Flash.BackgroundTransparency = 0.3
		tween(groupCard.Flash, 0.45, {BackgroundTransparency = 1})
		celebrateAt(groupCard.Buy, "+$" .. abbreviate(Config.Group.Money) .. " + GROUP SCOOPER!", GOLD)
		playSound("Unlock")
	else
		playSound("Error")
		shake(groupCard.Buy)
		if msg and msg ~= "" then toast(msg, RED) end
	end
end)

-- playtime: counts up from when you joined
local tiles = {}
for i, r in ipairs(Config.Playtime) do
	local btn = rw.Playtime["Reward" .. i]
	tiles[i] = btn
	btn.Amount.Text = "$" .. abbreviate(r.Money)
	bindButton(btn, function()
		if player:GetAttribute("Playtime_" .. i) then return end
		local ok, msg = Remotes.ClaimPlaytime:InvokeServer(i)
		if ok then
			btn.Icon.Rotation = -30
			tween(btn.Icon, 0.5, {Rotation = 0}, BACK)
			celebrateAt(btn, "+$" .. abbreviate(r.Money), GREEN)
		else
			playSound("Error")
			shake(btn)
			if msg and msg ~= "" then toast(msg, RED) end
		end
	end)
end
local lastReady = 0
local function updatePlaytime()
	local played = workspace:GetServerTimeNow() - (player:GetAttribute("JoinTime") or workspace:GetServerTimeNow())
	local ready = 0
	for i, r in ipairs(Config.Playtime) do
		local btn, status = tiles[i], tiles[i].Status
		local left = math.ceil(r.Minutes * 60 - played)
		if player:GetAttribute("Playtime_" .. i) then
			status.Text = "CLAIMED"
			btn.UIGradient.Color = BUY_MAX
		elseif left <= 0 then
			ready += 1
			status.Text = "CLAIM!"
			btn.UIGradient.Color = BUY_ON
		else
			status.Text = string.format("%d:%02d", left // 60, left % 60)
			btn.UIGradient.Color = BUY_OFF
		end
	end
	rewardsButton.Dot.Visible = ready > 0 or not player:GetAttribute("GroupReward")
	if ready > lastReady then
		-- a new reward is ready: give the button a little hop
		rewardsButton.Bounce.Scale = 1.3
		tween(rewardsButton.Bounce, 0.5, {Scale = 1}, BACK)
		playSound("Pop", 1.3)
		toast("Playtime reward ready!", GREEN)
	end
	lastReady = ready
end
task.spawn(function()
	while true do
		updatePlaytime()
		task.wait(0.5)
	end
end)

local rewardSteps = {
	{popEntry(likeCard), popEntry(likeCard.Tile)},
	{popEntry(groupCard), popEntry(groupCard.Tile)},
	{slideEntry(rw.PlaytimeHeader.Text)},
}
for i = 1, #tiles, 4 do
	local step = {}
	for j = i, math.min(i + 3, #tiles) do table.insert(step, popEntry(tiles[j])) end
	table.insert(rewardSteps, step)
end
menuSteps[RewardsMenu] = rewardSteps

---------------------------------------------------------------- admin panel (only for admins; the server checks too)
if Config.Admins[player.UserId] then
	AdminHUD.Visible = true
	local aw = AdminMenu.Window.Content
	bindButton(AdminHUD.AdminButton, function() toggleMenu(AdminMenu) end)
	local adminSteps = {{popEntry(aw.Target)}, {popEntry(aw.Amount)}, {popEntry(aw.Message)}}
	local function run(btn, action, extra, label)
		local amount = tonumber((aw.Amount.Input.Text:gsub("[,%s]", ""))) or 0
		local ok, msg = Remotes.AdminAction:InvokeServer(action, aw.Target.Input.Text, amount, extra)
		if ok then
			local c = centerOf(btn)
			popText(c.X, c.Y - 24 * uiScale, "DONE!", GREEN, 28, 40)
			burst(btn, 6)
			playSound("LevelUp")
			toast((label or textOf(btn).Text) .. " -> " .. msg, GREEN)
		else
			playSound("Error")
			shake(btn)
			toast(msg or "Failed", RED)
		end
		return ok
	end
	local row = {}
	for _, btn in ipairs(aw.Actions:GetChildren()) do
		if btn:IsA("GuiButton") then
			table.insert(row, popEntry(btn))
			bindButton(btn, function()
				local action, extra = btn.Name, nil
				if action:sub(1, 6) == "Event:" then action, extra = "Event", btn.Name:sub(7) end
				run(btn, action, extra)
			end)
		end
	end
	-- global message
	local msgBox = aw.Message.Input
	local function sendMessage()
		if msgBox.Text:match("^%s*$") then shake(aw.Message.Send) playSound("Error") return end
		if run(aw.Message.Send, "Message", msgBox.Text, "MESSAGE") then msgBox.Text = "" end
	end
	bindButton(aw.Message.Send, sendMessage)
	msgBox.FocusLost:Connect(function(enter) if enter then sendMessage() end end)
	-- chaos commands (global)
	for _, btn in ipairs(aw.Chaos:GetChildren()) do
		if btn:IsA("GuiButton") then
			bindButton(btn, function()
				if run(btn, "Chaos", btn.Name) then closeMenu(AdminMenu) end
			end)
		end
	end
	-- spawn any fish (Amount = how many, up to 50)
	for _, btn in ipairs(aw.FishList:GetChildren()) do
		if btn:IsA("GuiButton") then
			bindButton(btn, function() run(btn, "SpawnFish", btn.Name, btn.Name:upper()) end)
		end
	end
	table.insert(adminSteps, row)
	menuSteps[AdminMenu] = adminSteps
	-- the shield gently bobs
	local icon = AdminHUD.AdminButton.Icon
	RunService.RenderStepped:Connect(function()
		icon.Rotation = math.sin(os.clock() * 2) * 8
	end)
else
	AdminHUD:Destroy()
	AdminMenu:Destroy()
end

---------------------------------------------------------------- group reward preview (spinning scooper)
do
	local holder = groupCard.Rewards
	holder.Money.Amount.Text = "$" .. abbreviate(Config.Group.Money)
	local tool = ReplicatedStorage:WaitForChild("SpecialScoopers"):WaitForChild("Group Scooper")
	showModelIn(holder.Scooper.Preview, tool)
	table.insert(rewardSteps[2], popEntry(holder.Money))
	table.insert(rewardSteps[2], popEntry(holder.Scooper))
end

---------------------------------------------------------------- global announcements (admin messages, boss fish)
do
	local BOSS_COLOR = Color3.fromRGB(200, 120, 255)
	local function announceBig(title, sub, color)
		local items = {}
		local function label(text, size, y, c)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Font = Enum.Font.LuckiestGuy
			l.Text = text
			l.TextColor3 = c or WHITE
			l.TextSize = 1
			l.TextWrapped = true
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.new(0.5, 0, 0.3, y * uiScale)
			l.Size = UDim2.new(0.8, 0, 0, size * 2.4 * uiScale)
			l.ZIndex = 10
			local st = Instance.new("UIStroke"); st.Thickness = 4; st.Parent = l
			l.Parent = FX
			table.insert(items, l)
			tween(l, 0.5, {TextSize = size * uiScale}, BACK)
			return l
		end
		local rays = Instance.new("ImageLabel")
		rays.BackgroundTransparency = 1
		rays.Image = "rbxassetid://130341371819553"
		rays.ImageColor3 = color
		rays.ImageTransparency = 0.35
		rays.AnchorPoint = Vector2.new(0.5, 0.5)
		rays.Position = UDim2.new(0.5, 0, 0.3, 0)
		rays.Size = UDim2.new()
		rays.ZIndex = 9
		rays.Parent = FX
		tween(rays, 0.6, {Size = UDim2.fromOffset(620 * uiScale, 620 * uiScale)}, BACK)
		local head = label(title, #title > 24 and 44 or 70, -30, color)
		local g = Instance.new("UIGradient"); g.Rotation = 90; g.Color = seq({WHITE, color}); g.Parent = head
		if sub then task.delay(0.2, function() label(sub, 36, 40) end) end
		playSound("Swipe", 0.85)
		playSound("Unlock")
		local spin = RunService.RenderStepped:Connect(function()
			local t = os.clock()
			rays.Rotation = (t * 30) % 360
			head.Rotation = math.sin(t * 2.5) * 2
		end)
		task.delay(4.5, function()
			tween(rays, 0.4, {Size = UDim2.new()}, BACK, IN)
			for _, l in ipairs(items) do tween(l, 0.4, {TextSize = 1, TextTransparency = 1}, BACK, IN) end
			task.delay(0.45, function()
				spin:Disconnect()
				rays:Destroy()
				for _, l in ipairs(items) do l:Destroy() end
			end)
		end)
	end
	Remotes.Announce.OnClientEvent:Connect(function(text, kind, from, sub, color)
		if kind == "Chaos" then
			announceBig(text, sub, color or RED)
			shakeCamera(1.5, 0.5)
		elseif kind == "Boss" then
			announceBig("BOSS FISH!", "IT'S RAINING FISH FOR " .. Config.Boss.Duration .. " SECONDS!", BOSS_COLOR)
			shakeCamera(2.5, 0.8)
		else
			announceBig(text, from and ("- " .. from) or nil, Color3.fromRGB(255, 225, 80))
		end
	end)
end

---------------------------------------------------------------- luck boost timer (under the luck counter)
local boostLabel = LeftHUD.LuckCounter:FindFirstChild("BoostTimer")
if boostLabel then
	local shown = false
	RunService.RenderStepped:Connect(function()
		local left = (player:GetAttribute("LuckBoostEnds") or 0) - workspace:GetServerTimeNow()
		if left > 0 then
			left = math.ceil(left)
			boostLabel.Text = "x" .. (player:GetAttribute("LuckBoostMulti") or 1) .. " BOOST " .. string.format("%d:%02d", left // 60, left % 60)
			boostLabel.Rotation = math.sin(os.clock() * 3) * 2
			if not shown then
				shown = true
				boostLabel.Visible = true
				boostLabel.Bounce.Scale = 0
				tween(boostLabel.Bounce, 0.5, {Scale = 1}, BACK)
				burst(LeftHUD.LuckCounter, 10)
			end
		elseif shown then
			shown = false
			boostLabel.Visible = false
		end
	end)
end

-- the gift wiggles while something's waiting to be claimed
local giftIcon = rewardsButton.Icon
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	giftIcon.Rotation = rewardsButton.Dot.Visible and math.sin(t * 10) * 10 * math.max(0, math.sin(t * 1.5)) or 0
end)
end)()

;(function()
local GREEN = Color3.fromRGB(120, 255, 90)
local GOLD = Color3.fromRGB(255, 225, 80)
local BLACK_C = Color3.new(0, 0, 0)

---------------------------------------------------------------- fish index (collection book)
local IndexMenu = gui.IndexMenu
local iw = IndexMenu.Window
local indexButton = LeftHUD.IndexButton
IndexMenu.Visible = false
bindButton(iw.CloseButton, function() closeMenu(IndexMenu) end)
bindButton(indexButton, function() toggleMenu(IndexMenu) end)
local discovered = player:WaitForChild("Discovered")
local FishModels = ReplicatedStorage:WaitForChild("FishModels")
local cards, filled = {}, {}
for _, f in ipairs(Config.Fish) do cards[f.Name] = iw.Grid[f.Name] end

local function updateIndex()
	local names, count = {}, 0
	for _, v in ipairs(discovered:GetChildren()) do
		if cards[v.Name] then names[v.Name] = true count += 1 end
	end
	for _, f in ipairs(Config.Fish) do
		local card, found = cards[f.Name], names[f.Name]
		card.FishName.Text = found and f.Name:upper() or "???"
		if filled[f.Name] ~= (found and "found" or "hidden") then
			filled[f.Name] = found and "found" or "hidden"
			showModelIn(card.Preview, FishModels:FindFirstChild(f.Name), "fish")
		end
		-- undiscovered fish are black silhouettes
		card.Preview.ImageColor3 = found and WHITE or BLACK_C
		card.Preview.ImageTransparency = found and 0 or 0.25
	end
	local mult = Config.GetIndexMultiplier(names)
	iw.SubHeader.Text.Text = count .. "/" .. #Config.Fish .. " discovered  |  Index bonus x" .. trim(string.format("%.2f", mult))
end
updateIndex()
discovered.ChildAdded:Connect(function(v)
	updateIndex()
	-- new entry: the index button hops
	indexButton.Bounce.Scale = 1.4
	tween(indexButton.Bounce, 0.5, {Scale = 1}, BACK)
	indexButton.Dot.Visible = true
	local f = Config.Fish
	for _, info in ipairs(f) do
		if info.Name == v.Name then
			toast("INDEX: +" .. math.floor((Config.IndexBonus[info.Rarity] or 0) * 100 + 0.5) .. "% MONEY FOREVER!", GREEN)
		end
	end
end)
indexButton.Activated:Connect(function() indexButton.Dot.Visible = false end)
local indexSteps, row = {}, {}
for i, f in ipairs(Config.Fish) do
	table.insert(row, popEntry(cards[f.Name]))
	if #row == 4 or i == #Config.Fish then table.insert(indexSteps, row) row = {} end
	if #indexSteps >= 3 then break end -- (only the top rows animate; the rest are below the fold)
end
menuSteps[IndexMenu] = indexSteps

---------------------------------------------------------------- shop offers popping up on the side
do
	local promo = gui.Promo
	local card = promo.Card
	local SHOWN = promo.Position
	local HIDDEN = SHOWN + UDim2.fromOffset(700, 0)
	local current, token = nil, 0
	local prices = {}

	local function hide()
		token += 1
		if not promo.Visible then return end
		local tw = tween(promo, 0.35, {Position = HIDDEN}, BACK, IN)
		tw.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then promo.Visible = false end
		end)
	end

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
			while item == current do item = list[math.random(#list)] end
		end
		current = item
		token += 1
		local my = token
		local color = item.Color or Color3.fromRGB(120, 200, 255)
		card.Tile.UIGradient.Color = seq({color:Lerp(WHITE, 0.3), color:Lerp(BLACK, 0.25)})
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
		task.delay(0.25, function() tween(card.Tile.Icon.Bounce, 0.5, {Scale = 1}, BACK) burst(card, 10) end)
		playSound("Swipe", 1.1)
		task.delay(Config.Promo.Stay, function()
			if token == my then hide() end
		end)
	end

	bindButton(promo.Close, hide)
	bindButton(card.Buy, function()
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
			while openMenu or celebrating do task.wait(2) end
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

RunService.RenderStepped:Connect(function()
	indexButton.Icon.Rotation = math.sin(os.clock() * 2) * 6
end)

---------------------------------------------------------------- tutorial (first time only)
do
	local panel = gui.Tutorial
	local inner = panel.Inner
	local arrow = FX.TutorialArrow
	local hole = Config.Hole
	local skipped = false

	-- big bouncing arrow over the part of the ring hole closest to you
	local worldArrow
	local function makeWorldArrow()
		local a = Instance.new("Attachment")
		a.Parent = workspace.Terrain
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(110, 110)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Parent = a
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = arrow.Image
		img.Rotation = 180 -- pointing down into the hole
		img.Parent = bb
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(2, 0, 0.4, 0)
		label.Position = UDim2.new(-0.5, 0, -0.42, 0)
		label.Font = Enum.Font.LuckiestGuy
		label.Text = "PUSH FISH IN HERE!"
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 225, 80)
		local st = Instance.new("UIStroke"); st.Thickness = 3; st.Parent = label
		label.Parent = bb
		return a
	end

	-- each step: text, what to point at, and when it's done
	local function opened(menu) return function() return openMenu == menu end end
	local steps = {
		{Text = "Fish are raining from the sky! You're holding a SCOOPER, use it to push them around.", Min = 4},
		{Text = "Push fish into the RING HOLE around the island to sell them for money!", World = true,
			Done = function(s) return Collected.Value > s.Start end},
		{Text = "Nice! Keep collecting fish to unlock BIGGER SCOOPERS.", Target = ScooperBar, Side = "Top", Min = 5},
		{Text = "Spend your money on UPGRADES: faster spawns, more fish and more luck!", Target = RightHUD.UpgradeButton, Side = "Left",
			Done = opened(UpgradeMenu), Max = 25},
		{Text = "Every new fish you find goes in your INDEX and boosts your money forever!", Target = LeftHUD.IndexButton, Side = "Right",
			Done = opened(gui.IndexMenu), Max = 20},
		{Text = "When you're rich, REBIRTH for permanent luck. Good luck, catch them all!", Target = RightHUD.RebirthButton, Side = "Left", Min = 6},
	}

	local function placeArrow(target, side, t)
		local c = target.AbsolutePosition + target.AbsoluteSize / 2 + game:GetService("GuiService"):GetGuiInset()
		if not gui.IgnoreGuiInset then c -= game:GetService("GuiService"):GetGuiInset() end
		if arrow.Parent.AbsolutePosition.Y > 0 then c -= Vector2.new(0, arrow.Parent.AbsolutePosition.Y) end
		local size = target.AbsoluteSize
		local bob = math.sin(t * 6) * 12 * uiScale
		local pos, rot
		if side == "Left" then
			pos, rot = Vector2.new(c.X - size.X / 2 - 50 * uiScale - bob, c.Y), 90
		elseif side == "Right" then
			pos, rot = Vector2.new(c.X + size.X / 2 + 50 * uiScale + bob, c.Y), -90
		else
			pos, rot = Vector2.new(c.X, c.Y - size.Y / 2 - 50 * uiScale - bob), 180
		end
		arrow.Position = UDim2.fromOffset(pos.X, pos.Y)
		arrow.Rotation = rot
		arrow.Size = UDim2.fromOffset(80 * uiScale, 80 * uiScale)
	end

	local function finish()
		arrow.Visible = false
		if worldArrow then worldArrow:Destroy() worldArrow = nil end
		tween(inner.Pop, 0.3, {Scale = 0}, BACK, IN).Completed:Connect(function() panel.Visible = false end)
		Remotes.TutorialDone:FireServer()
	end

	bindButton(inner.Skip, function()
		skipped = true
		finish()
	end)

	local function run()
		panel.Visible = true
		inner.Pop.Scale = 0
		tween(inner.Pop, 0.5, {Scale = 1}, BACK)
		for i, step in ipairs(steps) do
			if skipped then return end
			inner.TitleBar.Title.Text = "TUTORIAL  " .. i .. "/" .. #steps
			inner.Body.Text = step.Text
			inner.Flash.BackgroundTransparency = 0.4
			tween(inner.Flash, 0.5, {BackgroundTransparency = 1})
			if i > 1 then
				inner.Pop.Scale = 0.85
				tween(inner.Pop, 0.4, {Scale = 1}, BACK)
				playSound("Pop", 0.9 + i * 0.08)
			end
			step.Start = Collected.Value
			arrow.Visible = step.Target ~= nil
			if step.World then worldArrow = makeWorldArrow() end
			local started = os.clock()
			while not skipped do
				local t = os.clock()
				local elapsed = t - started
				if step.Target then placeArrow(step.Target, step.Side, t) end
				if worldArrow then
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					local p = root and root.Position or hole.Center + Vector3.new(48, 0, 0)
					local flat = Vector3.new(p.X - hole.Center.X, 0, p.Z - hole.Center.Z)
					local d = math.max(math.abs(flat.X), math.abs(flat.Z), 0.01)
					local mid = (hole.Inner + hole.Outer) / 2
					worldArrow.WorldPosition = hole.Center + flat * (mid / d) + Vector3.new(0, 6 + math.sin(t * 5) * 1.5, 0)
				end
				local done
				if step.Done then
					done = step.Done(step) or (step.Max and elapsed > step.Max)
				else
					done = elapsed > (step.Min or 4)
				end
				if done and elapsed > 1.5 then break end
				RunService.RenderStepped:Wait()
			end
			if worldArrow then worldArrow:Destroy() worldArrow = nil end
			arrow.Visible = false
			if not skipped and step.Done then
				-- a little reward pop for doing the action
				playSound("LevelUp", 1.1)
				burst(inner, 12)
			end
		end
		if skipped then return end
		confettiBurst()
		playSound("Fanfare")
		inner.Body.Text = "You're ready! Have fun!"
		task.wait(2.5)
		finish()
	end

	task.spawn(function()
		-- the server says whether they've done it once their save has loaded
		while player:GetAttribute("TutorialDone") == nil do task.wait(0.5) end
		if player:GetAttribute("TutorialDone") then return end
		task.wait(2.5) -- let the HUD slide in first
		run()
	end)
end
end)()

---------------------------------------------------------------- intro
local leftPos, rightPos, barPos, bannerPos = LeftHUD.Position, RightHUD.Position, ScooperBar.Position, Banner.Position
LeftHUD.Position = leftPos - UDim2.fromOffset(500, 0)
RightHUD.Position = rightPos + UDim2.fromOffset(500, 0)
ScooperBar.Position = barPos + UDim2.fromOffset(0, 300)
Banner.Position = bannerPos - UDim2.fromOffset(0, 200)
task.wait(0.3)
tween(LeftHUD, 0.7, {Position = leftPos}, BACK)
tween(RightHUD, 0.7, {Position = rightPos}, BACK)
tween(ScooperBar, 0.8, {Position = barPos}, BACK)
tween(Banner, 0.8, {Position = bannerPos}, BACK)
