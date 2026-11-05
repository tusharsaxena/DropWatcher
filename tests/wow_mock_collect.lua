-- tests/wow_mock_collect.lua
--
-- The collection surface core/CompatCollect.lua reads (issue #13, categories design spec §2, §9),
-- split out of tests/wow_mock.lua to keep that file out of the 1000-line band. tests/wow_mock.lua's
-- builder calls this with the mock after its C_Item exists; every field is settable by a case.
--
-- Mock fields:
--   mounts       C_MountJournal: mounts.byItem[itemID] = mountID (GetMountFromItem);
--                mounts.collected[mountID] = true | false (GetMountInfoByID's 11th return, isCollected;
--                an unlisted mount answers nothing, as journal data not loaded yet does)
--   pets         C_PetJournal: pets.byItem[itemID] = speciesID (GetPetInfoByItemID's 13th return);
--                pets.counts[speciesID] = { count, limit } (GetNumCollectedInfo)
--   toys         C_ToyBox.GetToyInfo answers for toys[itemID] = true; toysOwned[itemID] = true is
--                PlayerHasToy's answer (false otherwise)
--   cosmetic     C_Item.IsCosmeticItem's answer: cosmetic[link] = true
--   professions  the player's professions' skill lines in GetProfessions' order (prof1, prof2,
--                archaeology, fishing, cooking); a false entry is a slot with no profession.
--                GetProfessionInfo(index) answers the skill line seventh
--   ITEM_SPELL_KNOWN  the enUS "Already known" line a known recipe's tooltip carries
--   INVTYPE_HEAD, _SHOULDER, _CHEST, _HAND, _LEGS  the enUS slot names a tier token's tooltip may
--                carry (Compat.TierTokenSlot, DW-CAT4)
--   itemSpells   C_Item.GetItemSpell(link) answers "Spell", itemSpells[link] (its spell id; nothing for
--                an item with no use spell); spellTexts[spellID] is C_Spell.GetSpellDescription's
--                answer (Compat.ItemUseText, TT-1)
--
-- The categories' Enum tables (ItemClass's Recipe, ItemMiscellaneousSubclass, ItemRecipeSubclass)
-- are left out on purpose, as the item ones are: core/Constants.lua then takes its documented
-- literals, which test_constants pins; a case that wants them passes its own Enum.

return function(M)
    M.mounts = { byItem = {}, collected = {} }
    M.C_MountJournal = {
        GetMountFromItem = function(itemID) return M.mounts.byItem[itemID] end,
        GetMountInfoByID = function(mountID)
            local known = M.mounts.collected[mountID]
            if known == nil then return nil end
            return "Mount", 1000, 0, false, true, 0, false, false, nil, false, known
        end,
    }

    M.pets = { byItem = {}, counts = {} }
    M.C_PetJournal = {
        GetPetInfoByItemID = function(itemID)
            local species = M.pets.byItem[itemID]
            if not species then return nil end
            return "Pet", 0, 0, 0, "", "", false, false, true, true, true, 0, species
        end,
        GetNumCollectedInfo = function(speciesID)
            local c = M.pets.counts[speciesID]
            if not c then return nil end
            return c[1], c[2]
        end,
    }

    M.toys, M.toysOwned = {}, {}
    M.C_ToyBox = {
        GetToyInfo = function(itemID)
            if not M.toys[itemID] then return nil end
            return itemID, "Toy " .. itemID, 134400, false, false, 1
        end,
    }
    M.PlayerHasToy = function(itemID) return M.toysOwned[itemID] == true end

    M.cosmetic = {}
    M.C_Item.IsCosmeticItem = function(link) return M.cosmetic[link] == true end

    M.professions = {}
    M.GetProfessions = function()
        local p, out = M.professions, {}
        for i = 1, 5 do out[i] = p[i] and i or nil end
        return out[1], out[2], out[3], out[4], out[5]
    end
    M.GetProfessionInfo = function(index)
        local line = M.professions[index]
        if not line then return nil end
        return "Profession " .. line, 134400, 1, 100, 0, 0, line
    end

    M.itemSpells, M.spellTexts = {}, {}
    M.C_Item.GetItemSpell = function(item)
        local id = M.itemSpells[item]
        if id == nil then return nil end
        return "Spell", id
    end
    M.C_Spell = { GetSpellDescription = function(spellID) return M.spellTexts[spellID] end }

    M.ITEM_SPELL_KNOWN = "Already known"
    M.INVTYPE_HEAD, M.INVTYPE_SHOULDER, M.INVTYPE_CHEST = "Head", "Shoulder", "Chest"
    M.INVTYPE_HAND, M.INVTYPE_LEGS = "Hands", "Legs"
end
