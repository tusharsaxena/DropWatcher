local _, NS = ...
-- core/GatherNodes.lua — the gathering nodes Item Search's Gathered from tab names a skill for (Item
-- Search round 3 spec §4.3, item 7). WoW Forever's alone: on Retail the table is empty.
--
-- HAND-CURATED, NOT GENERATED. ForeverDB's object rows carry a name and nothing else (its `oskill`
-- and `fish` tables are empty), and the client gives no static read of a node's required skill: the
-- "Requires Herbalism N" line appears only on the live node's tooltip. So each row here is a game
-- fact, the client's own minimum skill for that node, typed in by hand from the classic values: no
-- ForeverDB row is copied (its data is GPL-3.0; a node's name and its skill are the game's).
-- docs/validate-seeds.md lists it as a hand-curated list. The values are the classic client's;
-- VERIFY IN GAME (smoke row ITEM-SEARCH-37 checks them on WoW Forever).
--
-- Checked against the objects ForeverDB v2026.11.25.48 actually has (counts only, a scratch script
-- in no repo): every name below is the name of at least one object that drops something. Of the
-- 28 herbs and the 15 veins and deposits the spec started from, all are there, and 6 of the 15
-- "Ooze Covered" variants (the 9 others are no object in the build, so they are left out). Six
-- object names the patterns catch are not here (four Thorium or Iron variants and two herbs this
-- client adds): NS.ItemSearch.GatherKind still files them, with an unknown skill ("?").
--
--   NS.GatherNodes[name] = { prof = "herbalism" | "mining", skill = n }
-- Fishing has no per-node skill on this client, so no fishing node is listed. Each profession's skill
-- line (for the player's rank in it) is the model's, NS.ItemSearch.GATHER_LINE.

local NODES = {}
NS.GatherNodes = NODES

if NS.Compat.ClientKey() ~= "forever" then return end

local HERBS = {
    { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Earthroot", 15 }, { "Mageroyal", 50 }, { "Briarthorn", 70 },
    { "Stranglekelp", 85 }, { "Bruiseweed", 100 }, { "Wild Steelbloom", 115 }, { "Grave Moss", 120 },
    { "Kingsblood", 125 }, { "Liferoot", 150 }, { "Fadeleaf", 160 }, { "Goldthorn", 170 },
    { "Khadgar's Whisker", 185 }, { "Wintersbite", 195 }, { "Firebloom", 205 }, { "Purple Lotus", 210 },
    { "Arthas' Tears", 220 }, { "Sungrass", 230 }, { "Blindweed", 235 }, { "Ghost Mushroom", 245 },
    { "Gromsblood", 250 }, { "Golden Sansam", 260 }, { "Dreamfoil", 270 }, { "Mountain Silversage", 280 },
    { "Plaguebloom", 285 }, { "Icecap", 290 }, { "Black Lotus", 300 },
}

local VEINS = {
    { "Copper Vein", 1 }, { "Tin Vein", 65 }, { "Incendicite Mineral Vein", 65 }, { "Silver Vein", 75 },
    { "Lesser Bloodstone Deposit", 75 }, { "Iron Deposit", 125 }, { "Indurium Mineral Vein", 150 },
    { "Gold Vein", 155 }, { "Mithril Deposit", 175 }, { "Truesilver Deposit", 230 }, { "Dark Iron Deposit", 230 },
    { "Small Thorium Vein", 245 }, { "Rich Thorium Vein", 275 }, { "Small Obsidian Chunk", 305 },
    { "Large Obsidian Chunk", 305 },
}

-- The "Ooze Covered" variants the build has, each at its base vein's value.
local OOZE = { "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit", "Truesilver Deposit", "Rich Thorium Vein" }

local mining = {}
for _, h in ipairs(HERBS) do NODES[h[1]] = { prof = "herbalism", skill = h[2] } end
for _, v in ipairs(VEINS) do
    NODES[v[1]] = { prof = "mining", skill = v[2] }
    mining[v[1]] = v[2]
end
for _, base in ipairs(OOZE) do NODES["Ooze Covered " .. base] = { prof = "mining", skill = mining[base] } end
