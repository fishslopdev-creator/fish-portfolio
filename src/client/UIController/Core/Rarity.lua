-- Lookup tables for fish rarities: Rarity.Color["Epic"], Rarity.Order["Epic"] (1 = Common).
local Config = require(script.Parent.Context).Config

local Rarity = {Color = {}, Order = {}}
for i, r in ipairs(Config.Rarities) do
	Rarity.Color[r.Name] = r.Color
	Rarity.Order[r.Name] = i
end

return Rarity
