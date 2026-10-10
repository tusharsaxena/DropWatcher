local addonName, NS = ...
-- settings/Profiles.lua — the Profiles sub-page: AceConfigDialog drawing AceDBOptions' table
-- (options-ui-§3). Untabbed by rule (options-ui-§13). Registered last so it is the last
-- subcategory; built at first show.
local DW = NS.addon
local Settings  = DW.Settings
local L         = NS.L
local APPNAME = addonName .. "-Profiles"
local page
local function build(parentCategory)
    if not (_G.Settings and _G.Settings.RegisterCanvasLayoutSubcategory) then return nil end
    if not LibStub then return nil end
    local AceDBOptions    = LibStub("AceDBOptions-3.0", true)
    local AceConfig       = LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    local AceGUI          = LibStub("AceGUI-3.0", true)
    if not (AceDBOptions and AceConfig and AceConfigDialog and AceGUI) then return nil end
    local db = DW.db
    if not (db and db.profile) then return nil end
    local H = Settings.Helpers
    AceConfig:RegisterOptionsTable(APPNAME, AceDBOptions:GetOptionsTable(db))
    local ctx = H.CreatePanel(addonName .. "ProfilesPanel", L["Profiles"], {
        pageKey        = "profiles",
        defaultsButton = false,
    })
    local container
    H.SetRenderer(ctx, function()
        if not container then
            container = AceGUI:Create("SimpleGroup")
            container:SetLayout("Fill")
            container.frame:SetParent(ctx.body)
            container.frame:ClearAllPoints()
            container.frame:SetPoint("TOPLEFT", ctx.body, "TOPLEFT", 8, -8)
            container.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -8, 8)
        end
        container.frame:Show()
        AceConfigDialog:Open(APPNAME, container)
    end)
    page = ctx
    return _G.Settings.RegisterCanvasLayoutSubcategory(parentCategory, ctx.panel, L["Profiles"])
end
function Settings.RefreshProfilesPage()
    local H = Settings.Helpers
    if page and H and H.RefreshPanel then H.RefreshPanel(page, true) end
end
Settings.Helpers.RegisterOptionsPage("profiles", L["Profiles"], build)
