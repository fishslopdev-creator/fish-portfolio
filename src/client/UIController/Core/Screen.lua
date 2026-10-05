-- Scales the whole UI to the screen size. Screen.Scale is also read by effects that are drawn
-- in raw screen pixels (pop-up text, flying coins) so they match the rest of the UI.
local Context = require(script.Parent.Context)

local Screen = {Scale = 1}

local function updateScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local s = math.clamp(math.min(vp.X / 1440, vp.Y / 810), 0.45, 1.6) -- designed at 1440x810
	Screen.Scale = s
	for _, d in ipairs(Context.Gui:GetDescendants()) do
		if d:IsA("UIScale") and d.Name == "ScreenScale" then d.Scale = s end
	end
end

function Screen.start()
	updateScale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

return Screen
