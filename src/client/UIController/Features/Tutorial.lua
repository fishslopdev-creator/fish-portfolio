-- First-time tutorial: a short list of steps, each pointing an arrow at the relevant button
-- (or at the hole in the world) and waiting until the player has done it.
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Sound = require(Core.Sound)
local Buttons = require(Core.Buttons)
local Menus = require(Core.Menus)
local Screen = require(Core.Screen)
local VFX = require(Core.VFX)
local Celebration = require(Core.Celebration)

local gui, player = Context.Gui, Context.Player
local Collected = Context.Collected
local tween, BACK, IN = Util.tween, Util.BACK, Util.IN

local panel = gui.Tutorial
local inner = panel.Inner
local arrow = gui.FX.TutorialArrow
local hole = Context.Config.Hole

local Tutorial = {}

local skipped = false
local worldArrow

-- big bouncing arrow over the part of the ring hole closest to you
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
-- (Min = show for at least this long, Done = finished when this returns true, Max = give up waiting after this long)
local function opened(menu) return function() return Menus.Open == menu end end
local steps = {
	{Text = "Fish are raining from the sky! You're holding a SCOOPER, use it to push them around.", Min = 4},
	{Text = "Push fish into the RING HOLE around the island to sell them for money!", World = true,
		Done = function(s) return Collected.Value > s.Start end},
	{Text = "Nice! Keep collecting fish to unlock BIGGER SCOOPERS.", Target = gui.ScooperBar, Side = "Top", Min = 5},
	{Text = "Spend your money on UPGRADES: faster spawns, more fish and more luck!", Target = gui.RightHUD.UpgradeButton, Side = "Left",
		Done = opened(gui.UpgradeMenu), Max = 25},
	{Text = "Every new fish you find goes in your INDEX and boosts your money forever!", Target = gui.LeftHUD.IndexButton, Side = "Right",
		Done = opened(gui.IndexMenu), Max = 20},
	{Text = "When you're rich, REBIRTH for permanent luck. Good luck, catch them all!", Target = gui.RightHUD.RebirthButton, Side = "Left", Min = 6},
}

local function placeArrow(target, side, t)
	local uiScale = Screen.Scale
	local c = target.AbsolutePosition + target.AbsoluteSize / 2 + GuiService:GetGuiInset()
	if not gui.IgnoreGuiInset then c -= GuiService:GetGuiInset() end
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

-- keep the world arrow over the closest point of the square ring to the player
local function placeWorldArrow(t)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local p = root and root.Position or hole.Center + Vector3.new(48, 0, 0)
	local flat = Vector3.new(p.X - hole.Center.X, 0, p.Z - hole.Center.Z)
	local d = math.max(math.abs(flat.X), math.abs(flat.Z), 0.01)
	local mid = (hole.Inner + hole.Outer) / 2
	worldArrow.WorldPosition = hole.Center + flat * (mid / d) + Vector3.new(0, 6 + math.sin(t * 5) * 1.5, 0)
end

local function finish()
	arrow.Visible = false
	if worldArrow then worldArrow:Destroy() worldArrow = nil end
	tween(inner.Pop, 0.3, {Scale = 0}, BACK, IN).Completed:Connect(function() panel.Visible = false end)
	Context.Remotes.TutorialDone:FireServer()
end

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
			Sound.play("Pop", 0.9 + i * 0.08)
		end
		step.Start = Collected.Value
		arrow.Visible = step.Target ~= nil
		if step.World then worldArrow = makeWorldArrow() end
		local started = os.clock()
		while not skipped do
			local t = os.clock()
			local elapsed = t - started
			if step.Target then placeArrow(step.Target, step.Side, t) end
			if worldArrow then placeWorldArrow(t) end
			local done
			if step.Done then
				done = step.Done(step) or (step.Max and elapsed > step.Max)
			else
				done = elapsed > (step.Min or 4)
			end
			if done and elapsed > 1.5 then break end -- every step stays up long enough to read
			RunService.RenderStepped:Wait()
		end
		if worldArrow then worldArrow:Destroy() worldArrow = nil end
		arrow.Visible = false
		if not skipped and step.Done then
			-- a little reward pop for doing the action
			Sound.play("LevelUp", 1.1)
			VFX.burst(inner, 12)
		end
	end
	if skipped then return end
	Celebration.confettiBurst()
	Sound.play("Fanfare")
	inner.Body.Text = "You're ready! Have fun!"
	task.wait(2.5)
	finish()
end

function Tutorial.start()
	Buttons.bind(inner.Skip, function()
		skipped = true
		finish()
	end)

	task.spawn(function()
		-- the server says whether they've done it once their save has loaded
		while player:GetAttribute("TutorialDone") == nil do task.wait(0.5) end
		if player:GetAttribute("TutorialDone") then return end
		task.wait(2.5) -- let the HUD slide in first
		run()
	end)
end

return Tutorial
