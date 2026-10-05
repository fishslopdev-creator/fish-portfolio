-- Spinning 3D model previews inside ViewportFrames (scooper bar, celebration popup, fish index).
local RunService = game:GetService("RunService")

local ModelPreview = {}

local spinning = {} -- ViewportFrame -> {model, rel, tilt, mode, phase}

-- mode "fish": laid flat and framed from above, gently rocking; anything else: tilted and spinning
function ModelPreview.show(vpf, source, mode)
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
	local rel = cf:ToObjectSpace(model:GetPivot()) -- rotate around the visual centre, not the pivot
	local tilt = mode == "fish" and CFrame.Angles(math.rad(80), 0, 0) or CFrame.Angles(math.rad(28), 0, 0)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	-- back the camera off just far enough for the model to fill the frame
	local radius = (mode == "fish" and math.max(size.X, size.Z) or size.Magnitude) * 0.5
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * (mode == "fish" and 1.08 or 0.85)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, dist), Vector3.zero)
	cam.Parent = vpf
	vpf.CurrentCamera = cam
	model.Parent = vpf
	spinning[vpf] = {model = model, rel = rel, tilt = tilt, mode = mode, phase = math.random() * 6}
	model:PivotTo(tilt * rel)
end

function ModelPreview.start()
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for vpf, e in pairs(spinning) do
			if vpf.Parent and vpf.Visible then
				local yaw = e.mode == "fish" and math.sin(t * 1.6 + e.phase) * 0.5 or t * 1.4 + e.phase
				local bob = CFrame.new(0, math.sin(t * 3 + e.phase) * 0.15, 0)
				e.model:PivotTo(bob * CFrame.Angles(0, yaw, 0) * e.tilt * e.rel)
			end
		end
	end)
end

return ModelPreview
