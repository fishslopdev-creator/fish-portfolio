-- 3D effects in the world: flying stud debris, square ring blasts and floating billboard text.
-- Everything is client-side only and lives in workspace.ClientFX.
local Util = require(script.Parent.Util)

local tween, QUAD, QUART, BACK, IN = Util.tween, Util.QUAD, Util.QUART, Util.BACK, Util.IN

local WorldFX = {
	GrassColor = Color3.fromRGB(90, 200, 80), -- grass colour right now (seasonal events change it)
}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientFX"
fxFolder.Parent = workspace
WorldFX.Folder = fxFolder

local SURFACES = {"TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface"}

-- an anchored, non-colliding part with classic studs on every face
function WorldFX.studPart(size, color, cf, transparency)
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

function WorldFX.randomAngles()
	return CFrame.Angles(math.random() * 6.3, math.random() * 6.3, math.random() * 6.3)
end

-- little stud cubes flying out
function WorldFX.debris(pos, colors, n, power)
	for _ = 1, n do
		local s = 0.5 + math.random() * 0.6
		local p = WorldFX.studPart(Vector3.one * s, colors[math.random(#colors)], CFrame.new(pos) * WorldFX.randomAngles())
		local dir = Vector3.new(math.random() - 0.5, 0.5 + math.random() * 0.9, math.random() - 0.5).Unit
		local peak = pos + dir * power * (0.5 + math.random() * 0.7)
		local t = 0.3 + math.random() * 0.15
		tween(p, t, {CFrame = CFrame.new(peak) * WorldFX.randomAngles()}, QUAD)
		task.delay(t, function()
			tween(p, 0.4, {CFrame = CFrame.new(peak - Vector3.new(0, power * 0.6, 0)) * WorldFX.randomAngles(), Size = Vector3.one * 0.05, Transparency = 1}, QUAD, IN)
		end)
		task.delay(t + 0.42, p.Destroy, p)
	end
end

-- square stud ring that blasts outward (matches the square hole)
function WorldFX.ringBlast(pos, color, size)
	for i = 0, 3 do
		local side = CFrame.Angles(0, i * math.pi / 2, 0)
		local p = WorldFX.studPart(Vector3.new(2, 0.6, 0.6), color, CFrame.new(pos) * side * CFrame.new(0, 0, 1), 0.1)
		local goal = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * side * CFrame.new(0, 0, size / 2)
		tween(p, 0.55, {CFrame = goal, Size = Vector3.new(size, 0.6, 0.6), Transparency = 1}, QUART)
		task.delay(0.6, p.Destroy, p)
	end
end

-- "+$1.2K" floating up out of the hole
function WorldFX.worldText(pos, text, color, size, rainbow)
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
		local g = Instance.new("UIGradient"); g.Name = "Rainbow"; g.Color = Util.rainbowSeq(os.clock()); g.Parent = l
	end
	tween(l, 0.35, {TextSize = size}, BACK)
	tween(bb, 1.4, {StudsOffsetWorldSpace = Vector3.new(0, 9, 0)}, QUART)
	task.delay(0.8, function()
		tween(l, 0.5, {TextTransparency = 1}, QUAD, IN)
		tween(st, 0.5, {Transparency = 1}, QUAD, IN)
	end)
	task.delay(1.4, a.Destroy, a)
end

return WorldFX
