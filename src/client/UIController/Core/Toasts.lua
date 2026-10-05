-- The short message that drops in at the top of the screen ("Not enough money!", "EPIC CATCH!" ...).
local Context = require(script.Parent.Context)
local Util = require(script.Parent.Util)
local Screen = require(script.Parent.Screen)

local Toast = Context.Gui.Toast
local HIDDEN = UDim2.new(0.5, 0, 0, -120)

local Toasts = {}

local toastId = 0
function Toasts.show(text, color)
	toastId += 1
	local id = toastId
	Toast.Text = text
	Toast.TextColor3 = color or Util.WHITE
	Toast.Position = HIDDEN
	Util.tween(Toast, 0.4, {Position = UDim2.new(0.5, 0, 0, 24 + 82 * Screen.Scale)}, Util.BACK) -- just under the event banner
	task.delay(2.2, function()
		-- only hide if a newer toast hasn't replaced this one
		if id == toastId then Util.tween(Toast, 0.3, {Position = HIDDEN}, Util.BACK, Util.IN) end
	end)
end

function Toasts.start()
	Context.Remotes.Notify.OnClientEvent:Connect(Toasts.show)
end

return Toasts
