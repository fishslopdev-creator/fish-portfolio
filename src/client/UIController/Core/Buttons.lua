-- Gives a button the shared hover / press "bounce" feel and click sound.
local Util = require(script.Parent.Util)
local Sound = require(script.Parent.Sound)

local Buttons = {}

function Buttons.bind(btn, onClick)
	local scale = btn:FindFirstChild("Bounce") or Instance.new("UIScale", btn)
	local hovering = false
	btn.MouseEnter:Connect(function()
		hovering = true
		Sound.play("Hover")
		Util.tween(scale, 0.18, {Scale = 1.07}, Util.BACK)
	end)
	btn.MouseLeave:Connect(function()
		hovering = false
		Util.tween(scale, 0.18, {Scale = 1}, Util.BACK)
	end)
	btn.MouseButton1Down:Connect(function()
		Util.tween(scale, 0.08, {Scale = 0.9})
	end)
	btn.MouseButton1Up:Connect(function()
		Util.tween(scale, 0.25, {Scale = hovering and 1.07 or 1}, Util.BACK)
	end)
	btn.Activated:Connect(function()
		Sound.play("Click")
		onClick()
	end)
end

return Buttons
