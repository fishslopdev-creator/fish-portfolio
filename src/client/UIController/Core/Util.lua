-- Small helpers used all over the UI: tweening, colour sequences, number formatting and shared colours.
local TweenService = game:GetService("TweenService")

local Util = {}

Util.BACK, Util.QUAD, Util.QUART = Enum.EasingStyle.Back, Enum.EasingStyle.Quad, Enum.EasingStyle.Quart
Util.IN = Enum.EasingDirection.In

Util.WHITE, Util.BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
Util.RED = Color3.fromRGB(255, 80, 80)
Util.GREEN = Color3.fromRGB(120, 255, 90)
Util.GOLD = Color3.fromRGB(255, 225, 80)
Util.ROBUX = "\u{E002} "

function Util.tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Util.QUAD, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- evenly spaced ColorSequence from a list of colours
function Util.seq(colors)
	local kps = {}
	for i, c in ipairs(colors) do
		kps[i] = ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c)
	end
	return ColorSequence.new(kps)
end

-- a 5-stop rainbow that scrolls over time
function Util.rainbowSeq(t)
	local kps = {}
	for i = 0, 4 do
		kps[i + 1] = ColorSequenceKeypoint.new(i / 4, Color3.fromHSV((t * 0.25 + i * 0.18) % 1, 0.7, 1))
	end
	return ColorSequence.new(kps)
end

-- button gradients shared by the upgrade, trail and reward menus
Util.BUY_ON = Util.seq({Color3.fromRGB(170, 255, 70), Color3.fromRGB(40, 185, 45)})
Util.BUY_OFF = Util.seq({Color3.fromRGB(190, 190, 195), Color3.fromRGB(110, 110, 120)})
Util.BUY_MAX = Util.seq({Color3.fromRGB(255, 235, 80), Color3.fromRGB(255, 160, 0)})

---------------------------------------------------------------- number formatting
local SUFFIXES = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}

-- "1.50" -> "1.5", "2.00" -> "2"
function Util.trim(s)
	if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
	return s
end

-- 1234 -> "1.23K", 45600000 -> "45.6M"
function Util.abbreviate(n)
	if n < 1000 then return tostring(math.floor(n)) end
	local i = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local v = n / 10 ^ (i * 3)
	local s = v >= 100 and tostring(math.floor(v)) or v >= 10 and string.format("%.1f", v) or string.format("%.2f", v)
	return Util.trim(s) .. SUFFIXES[i + 1]
end

-- 1234567 -> "1,234,567"
function Util.commas(n)
	local s, k = tostring(math.floor(n)), 0
	repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
	return s
end

-- multipliers: "1.5x", "12,500x", then abbreviated once they get huge
function Util.formatLuck(n)
	if n < 1000 then return Util.trim(string.format("%.2f", n)) .. "x" end
	if n < 1e9 then return Util.commas(n) .. "x" end
	return Util.abbreviate(n) .. "x"
end

---------------------------------------------------------------- gui helpers
-- quick horizontal wobble, used for "can't do that" feedback
function Util.shake(obj)
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

function Util.centerOf(obj)
	return obj.AbsolutePosition + obj.AbsoluteSize / 2
end

return Util
