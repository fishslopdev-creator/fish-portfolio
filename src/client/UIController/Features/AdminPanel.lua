-- Admin panel: give money / luck, start events, chaos commands, global messages and spawning fish.
-- Only shown to admins listed in Config; every action is checked again on the server.
local RunService = game:GetService("RunService")
local Core = script.Parent.Parent.Core
local Context = require(Core.Context)
local Util = require(Core.Util)
local Sound = require(Core.Sound)
local Buttons = require(Core.Buttons)
local Toasts = require(Core.Toasts)
local Menus = require(Core.Menus)
local Screen = require(Core.Screen)
local VFX = require(Core.VFX)

local AdminMenu, AdminHUD = Context.Gui.AdminMenu, Context.Gui.AdminHUD
local GREEN, RED = Util.GREEN, Util.RED

local AdminPanel = {}

local function textOf(btn) return btn:FindFirstChild("Text") or btn:FindFirstChild("Status") end

function AdminPanel.start()
	if not Context.Config.Admins[Context.Player.UserId] then
		AdminHUD:Destroy()
		AdminMenu:Destroy()
		return
	end

	Menus.register(AdminMenu)
	AdminHUD.Visible = true
	local aw = AdminMenu.Window.Content
	Buttons.bind(AdminHUD.AdminButton, function() Menus.toggle(AdminMenu) end)

	-- sends one admin action with the target / amount typed into the panel
	local function run(btn, action, extra, label)
		local amount = tonumber((aw.Amount.Input.Text:gsub("[,%s]", ""))) or 0
		local ok, msg = Context.Remotes.AdminAction:InvokeServer(action, aw.Target.Input.Text, amount, extra)
		if ok then
			local c = Util.centerOf(btn)
			VFX.popText(c.X, c.Y - 24 * Screen.Scale, "DONE!", GREEN, 28, 40)
			VFX.burst(btn, 6)
			Sound.play("LevelUp")
			Toasts.show((label or textOf(btn).Text) .. " -> " .. msg, GREEN)
		else
			Sound.play("Error")
			Util.shake(btn)
			Toasts.show(msg or "Failed", RED)
		end
		return ok
	end

	-- action buttons are named after the action ("GiveMoney", "Event:Winter" ...)
	local row = {}
	for _, btn in ipairs(aw.Actions:GetChildren()) do
		if btn:IsA("GuiButton") then
			table.insert(row, Menus.popEntry(btn))
			Buttons.bind(btn, function()
				local action, extra = btn.Name, nil
				if action:sub(1, 6) == "Event:" then action, extra = "Event", btn.Name:sub(7) end
				run(btn, action, extra)
			end)
		end
	end

	-- global message
	local msgBox = aw.Message.Input
	local function sendMessage()
		if msgBox.Text:match("^%s*$") then Util.shake(aw.Message.Send) Sound.play("Error") return end
		if run(aw.Message.Send, "Message", msgBox.Text, "MESSAGE") then msgBox.Text = "" end
	end
	Buttons.bind(aw.Message.Send, sendMessage)
	msgBox.FocusLost:Connect(function(enter) if enter then sendMessage() end end)

	-- chaos commands (global)
	for _, btn in ipairs(aw.Chaos:GetChildren()) do
		if btn:IsA("GuiButton") then
			Buttons.bind(btn, function()
				if run(btn, "Chaos", btn.Name) then Menus.close(AdminMenu) end
			end)
		end
	end

	-- spawn any fish (Amount = how many, up to 50)
	for _, btn in ipairs(aw.FishList:GetChildren()) do
		if btn:IsA("GuiButton") then
			Buttons.bind(btn, function() run(btn, "SpawnFish", btn.Name, btn.Name:upper()) end)
		end
	end

	Menus.Steps[AdminMenu] = {{Menus.popEntry(aw.Target)}, {Menus.popEntry(aw.Amount)}, {Menus.popEntry(aw.Message)}, row}

	-- the shield gently bobs
	local icon = AdminHUD.AdminButton.Icon
	RunService.RenderStepped:Connect(function()
		icon.Rotation = math.sin(os.clock() * 2) * 8
	end)
end

return AdminPanel
