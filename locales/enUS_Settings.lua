local _, NS = ...
-- locales/enUS_Settings.lua — the settings panel's strings (settings/), a topic file split out of
-- locales/enUS.lua when the tooltip rows (feedback-21) took it past layout-§1's 1500-line cap, on
-- localization-§6's shape. locales/enUS.lua loads first (DropWatcher.toc) and alone creates NS.L and
-- its metatable fallback; this file only fills that table. Each key lives in one enUS file, so a key
-- a module also reads stays in enUS.lua, the file of its first reader in TOC load order, and this
-- file holds only what settings/ alone reads. The key IS the English source string, one heading per
-- first user in TOC load order, as there.

local L = NS.L

-- settings/SchemaRows.lua
L["Use global"] = "Use global"
L["A fresh tab lists only the drops that are an upgrade for you, or that their looter is likely to give away and can trade. With none ticked, a fresh tab lists every drop."] =
    "A fresh tab lists only the drops that are an upgrade for you, or that their looter is likely to give away and can trade. With none ticked, a fresh tab lists every drop."
L["A fresh tab lists only the drops whose trade estimate is yes or likely. With none ticked, a fresh tab lists every drop."] =
    "A fresh tab lists only the drops whose trade estimate is yes or likely. With none ticked, a fresh tab lists every drop."
L["A fresh tab hides the drops you can't use and the item types you marked as unwanted. With none ticked, a fresh tab lists every drop."] =
    "A fresh tab hides the drops you can't use and the item types you marked as unwanted. With none ticked, a fresh tab lists every drop."
L["A fresh tab lists only the drops that are an upgrade for you. With none ticked, a fresh tab lists every drop."] =
    "A fresh tab lists only the drops that are an upgrade for you. With none ticked, a fresh tab lists every drop."
L["Newest"] = "Newest"
L["Oldest"] = "Oldest"
L["Gain"] = "Gain"
L["Off"] = "Off"
L["Absolute"] = "Absolute"
L["Relative to my gear"] = "Relative to my gear"
L["Automatic"] = "Automatic"
L["My weights"] = "My weights"
L["None"] = "None"
L["Party"] = "Party"
L["Full"] = "Full"
L["Compact"] = "Compact"
L["Personal loot"] = "Personal loot"
L["Auto-open the window"] = "Auto-open the window"
L["Open the window whenever a drop is added to the feed in a situation set to auto-open, your own included. A minimized window stays minimized and counts it. Off, no situation opens it."] =
    "Open the window whenever a drop is added to the feed in a situation set to auto-open, your own included. A minimized window stays minimized and counts it. Off, no situation opens it."
L["Watch the loot in this situation. Off, drops here are ignored and nobody is inspected for them."] =
    "Watch the loot in this situation. Off, drops here are ignored and nobody is inspected for them."
L["Auto-open"] = "Auto-open"
L["Open the window whenever a drop here is added to the feed."] =
    "Open the window whenever a drop here is added to the feed."
L["The minimum quality here: the feed's own mode, or one of its own."] =
    "The minimum quality here: the feed's own mode, or one of its own."
L["Minimum quality"] = "Minimum quality"
L["Fixed: one quality for every drop. Match each slot: the quality of what the drop would replace. Match my gear: the quality most of your gear is."] =
    "Fixed: one quality for every drop. Match each slot: the quality of what the drop would replace. Match my gear: the quality most of your gear is."
L["The least quality a drop needs in the fixed mode."] = "The least quality a drop needs in the fixed mode."
L["The least quality the two matching modes ever ask for, and what an empty slot asks for."] =
    "The least quality the two matching modes ever ask for, and what an empty slot asks for."
L["Always show upgrades for me"] = "Always show upgrades for me"
L["A drop below the minimum still shows when it is an upgrade for you."] =
    "A drop below the minimum still shows when it is an upgrade for you."
L["Which drops the Drops tab lists when it opens: this instance's or this session's. History always opens on All."] =
    "Which drops the Drops tab lists when it opens: this instance's or this session's. History always opens on All."
L["How a fresh tab sorts its rows."] = "How a fresh tab sorts its rows."
L["Gear only"] = "Gear only"
L["List armor, weapons, jewelry and trinkets only."] = "List armor, weapons, jewelry and trinkets only."
L["Include tier tokens"] = "Include tier tokens"
L["List tier tokens too."] = "List tier tokens too."
L["Minimum item level"] = "Minimum item level"
L["Off, absolute (the level below), or relative (how far under your average equipped level a drop may be)."] =
    "Off, absolute (the level below), or relative (how far under your average equipped level a drop may be)."
L["Absolute minimum"] = "Absolute minimum"
L["The least item level a drop needs in the absolute mode."] = "The least item level a drop needs in the absolute mode."
L["Levels under my average"] = "Levels under my average"
L["How far under your average equipped item level a drop may be in the relative mode."] =
    "How far under your average equipped item level a drop may be in the relative mode."
L["Clear this session's drops on boss kill"] = "Clear this session's drops on boss kill"
L["Clear the session's drops when a boss dies."] = "Clear the session's drops when a boss dies."
L["Scoring"] = "Scoring"
L["Score with"] = "Score with"
L["Automatic uses Pawn once it has loaded and initialized, else your weights, else item level alone."] =
    "Automatic uses Pawn once it has loaded and initialized, else your weights, else item level alone."
L["Sidegrade band"] = "Sidegrade band"
L["Item levels either side of equal that still read as a sidegrade."] =
    "Item levels either side of equal that still read as a sidegrade."
L["Compare against items in my bags"] = "Compare against items in my bags"
L["Judge a drop against the best of what you wear and what you carry."] =
    "Judge a drop against the best of what you wear and what you carry."
L["Protect heirlooms"] = "Protect heirlooms"
L["A drop for a slot that holds an heirloom is not called an upgrade."] =
    "A drop for a slot that holds an heirloom is not called an upgrade."
L["Stat weights"] = "Stat weights"
L["Your stat weights for each specialization."] = "Your stat weights for each specialization."
L["Unwanted item types"] = "Unwanted item types"
L["The item types each specialization never wants."] = "The item types each specialization never wants."
L["The loot rule that decides whether a drop here can be traded."] =
    "The loot rule that decides whether a drop here can be traded."
L["Templates"] = "Templates"
L["What you whisper a looter to ask for their drop."] = "What you whisper a looter to ask for their drop."
L["What you whisper a looter to ask for a drop that is no gain for you but whose look you have not collected."] =
    "What you whisper a looter to ask for a drop that is no gain for you but whose look you have not collected."
L["What you whisper a looter to ask for a drop your current spec can't use but another of your specs gains from."] =
    "What you whisper a looter to ask for a drop your current spec can't use but another of your specs gains from."
L["What you whisper someone your own drop would help."] = "What you whisper someone your own drop would help."
L["What you tell the group about a drop you can trade."] = "What you tell the group about a drop you can trade."
L["Sending"] = "Sending"
L["Edit before sending"] = "Edit before sending"
L["Open the message in an edit box before it is sent."] = "Open the message in an edit box before it is sent."
L["Ask once"] = "Ask once"
L["Send each ask or offer for a drop to a player once."] = "Send each ask or offer for a drop to a player once."
L["Announce channel"] = "Announce channel"
L["Automatic picks the instance channel, then raid, then party. Never say or yell."] =
    "Automatic picks the instance channel, then raid, then party. Never say or yell."
L["Auto-ask"] = "Auto-ask"
L["Ask automatically"] = "Ask automatically"
L["Ask for a likely tradeable upgrade for you on your behalf, after a delay."] =
    "Ask for a likely tradeable upgrade for you on your behalf, after a delay."
L["Delay (seconds)"] = "Delay (seconds)"
L["How long after the boss kill, or the drop, the ask waits."] =
    "How long after the boss kill, or the drop, the ask waits."
L["Least gain (item levels)"] = "Least gain (item levels)"
L["The least item-level gain for you an automatic ask needs."] =
    "The least item-level gain for you an automatic ask needs."
L["Columns"] = "Columns"
L["Layout"] = "Layout"
L["Full shows the drop tables with every column. Compact shows the same drops in a narrow window, so it stays out of the way during a run. The title bar's toggle, /dw compact and /dw full switch it too."] =
    "Full shows the drop tables with every column. Compact shows the same drops in a narrow window, so it stays out of the way during a run. The title bar's toggle, /dw compact and /dw full switch it too."
L["Compact view when it auto-opens in a run"] = "Compact view when it auto-opens in a run"
L["Tables"] = "Tables"
L["When the window opens by itself inside a dungeon, raid, Mythic+ key or delve, it opens in compact view, whatever the Layout. After the run ends it opens in the Layout again."] =
    "When the window opens by itself inside a dungeon, raid, Mythic+ key or delve, it opens in compact view, whatever the Layout. After the run ends it opens in the Layout again."
L["Row height"] = "Row height"
L["The height of one row in the drop tables: Drops and History. While the Trade window column shows, a Drops row adds room for its countdown bar."] =
    "The height of one row in the drop tables: Drops and History. While the Trade window column shows, a Drops row adds room for its countdown bar."
L["Font size"] = "Font size"
L["The size of the drop tables' text, on both tabs. All the way left (0) is Default: the game's own small table font, as in Ka0s Loot History."] =
    "The size of the drop tables' text, on both tabs. All the way left (0) is Default: the game's own small table font, as in Ka0s Loot History."
L["Default"] = "Default"
L["Toast"] = "Toast"
L["Show a toast"] = "Show a toast"
L["Pop up a toast for a likely tradeable upgrade for you."] = "Pop up a toast for a likely tradeable upgrade for you."
L["The least item-level gain for you a toast needs."] = "The least item-level gain for you a toast needs."
L["Duration (seconds)"] = "Duration (seconds)"
L["How long a toast stays on screen."] = "How long a toast stays on screen."
L["Show in combat"] = "Show in combat"
L["Show toasts in combat too."] = "Show toasts in combat too."
L["Play a sound"] = "Play a sound"
L["Play a sound with each toast."] = "Play a sound with each toast."
L["Scale"] = "Scale"
L["The toast's size, from half to double. It grows or shrinks about the place you put it."] =
    "The toast's size, from half to double. It grows or shrinks about the place you put it."
L["Upgrade glow"] = "Upgrade glow"
L["Pixel border"] = "Pixel border"
L["Main spec lines"] = "Main spec lines"
L["Off-spec lines"] = "Off-spec lines"
L["How many lines run around the icon. Pixel style only."] =
    "How many lines run around the icon. Pixel style only."
L["Main spec frequency"] = "Main spec frequency"
L["Off-spec frequency"] = "Off-spec frequency"
L["How fast the lines run around the icon. Higher is faster. Pixel style only."] =
    "How fast the lines run around the icon. Higher is faster. Pixel style only."
L["Main spec line length (0 = automatic)"] = "Main spec line length (0 = automatic)"
L["Off-spec line length (0 = automatic)"] = "Off-spec line length (0 = automatic)"
L["How long each line is, in pixels. 0 sizes the lines from the icon. Pixel style only."] =
    "How long each line is, in pixels. 0 sizes the lines from the icon. Pixel style only."
L["Main spec thickness"] = "Main spec thickness"
L["Off-spec thickness"] = "Off-spec thickness"
L["How thick each line is, in pixels. Pixel style only."] =
    "How thick each line is, in pixels. Pixel style only."
L["Main spec dark border"] = "Main spec dark border"
L["Off-spec dark border"] = "Off-spec dark border"
L["Draw a dark border inside the lines. Pixel style only."] =
    "Draw a dark border inside the lines. Pixel style only."
L["Auto cast sparkles"] = "Auto cast sparkles"
L["Main spec particles"] = "Main spec particles"
L["Off-spec particles"] = "Off-spec particles"
L["How many sparkles circle the icon in each ring. Auto cast style only."] =
    "How many sparkles circle the icon in each ring. Auto cast style only."
L["How fast the sparkles circle the icon. Higher is faster. Auto cast style only."] =
    "How fast the sparkles circle the icon. Higher is faster. Auto cast style only."
L["Main spec scale"] = "Main spec scale"
L["Off-spec scale"] = "Off-spec scale"
L["How big the sparkles are. Auto cast style only."] =
    "How big the sparkles are. Auto cast style only."
L["Button (rotating rays)"] = "Button (rotating rays)"
L["How fast the rays turn. Higher is faster. Button style only."] =
    "How fast the rays turn. Higher is faster. Button style only."
L["Proc (flipbook)"] = "Proc (flipbook)"
L["Main spec duration (seconds)"] = "Main spec duration (seconds)"
L["Off-spec duration (seconds)"] = "Off-spec duration (seconds)"
L["How many seconds one loop of the flipbook takes. Proc style only."] =
    "How many seconds one loop of the flipbook takes. Proc style only."
L["Main spec start animation"] = "Main spec start animation"
L["Off-spec start animation"] = "Off-spec start animation"
L["Play the burst that opens the proc glow when it starts. Proc style only."] =
    "Play the burst that opens the proc glow when it starts. Proc style only."
L["Offset"] = "Offset"
L["Main spec X offset"] = "Main spec X offset"
L["Off-spec X offset"] = "Off-spec X offset"
L["How far the glow reaches past the icon's sides, in pixels. Pixel, Proc and Auto cast styles."] =
    "How far the glow reaches past the icon's sides, in pixels. Pixel, Proc and Auto cast styles."
L["Main spec Y offset"] = "Main spec Y offset"
L["Off-spec Y offset"] = "Off-spec Y offset"
L["How far the glow reaches past the icon's top and bottom, in pixels. Pixel, Proc and Auto cast styles."] =
    "How far the glow reaches past the icon's top and bottom, in pixels. Pixel, Proc and Auto cast styles."
L["Effect"] = "Effect"
L["Main spec glow"] = "Main spec glow"
L["Glow a drop's icon when it is an upgrade for your current spec: in the drop table, the compact card and the drop's card."] =
    "Glow a drop's icon when it is an upgrade for your current spec: in the drop table, the compact card and the drop's card."
L["Off-spec glow"] = "Off-spec glow"
L["Glow a drop's icon when your current spec can't use it but another of your specs gains from it: in the drop table, the compact card and the drop's card."] =
    "Glow a drop's icon when your current spec can't use it but another of your specs gains from it: in the drop table, the compact card and the drop's card."
L["Main spec style"] = "Main spec style"
L["How the main spec glow looks."] = "How the main spec glow looks."
L["Off-spec style"] = "Off-spec style"
L["How the off-spec glow looks."] = "How the off-spec glow looks."
L["Main spec color"] = "Main spec color"
L["Off-spec color"] = "Off-spec color"
L["The glow's color. Its alpha makes the glow fainter. Not read while Use class color is on, except for its opacity, which always applies."] =
    "The glow's color. Its alpha makes the glow fainter. Not read while Use class color is on, except for its opacity, which always applies."
L["Use class color (main spec)"] = "Use class color (main spec)"
L["Use class color (off-spec)"] = "Use class color (off-spec)"
L["Glow in your class color instead of Main spec color, the swatch above. The swatch's alpha still applies."] =
    "Glow in your class color instead of Main spec color, the swatch above. The swatch's alpha still applies."
L["Glow in your class color instead of Off-spec color, the swatch above. The swatch's alpha still applies."] =
    "Glow in your class color instead of Off-spec color, the swatch above. The swatch's alpha still applies."
L["Icons"] = "Icons"
L["Zoom"] = "Zoom"
L["Icon zoom"] = "Icon zoom"
L["Crop each item icon's edges: 0 shows the whole icon, 0.25 crops a quarter off each side. A little zoom trims the dark edge baked into most item icons."] =
    "Crop each item icon's edges: 0 shows the whole icon, 0.25 crops a quarter off each side. A little zoom trims the dark edge baked into most item icons."

L["Skin source"] = "Skin source"
L["Where this addon's look comes from: the Ka0s skin chosen below, or EllesmereUI."] =
    "Where this addon's look comes from: the Ka0s skin chosen below, or EllesmereUI."
L["Skin"] = "Skin"
L["The Ka0s skin this addon wears. Changes every window and panel right away."] =
    "The Ka0s skin this addon wears. Changes every window and panel right away."
L["Ignore settings panel"] = "Ignore settings panel"
L["Keep this addon's settings panel in the game's own look. Its windows still wear the skin."] =
    "Keep this addon's settings panel in the game's own look. Its windows still wear the skin."
L["Ignore fonts"] = "Ignore fonts"
L["Keep every font in this addon as the game draws it. The skin still colors the text."] =
    "Keep every font in this addon as the game draws it. The skin still colors the text."
L["Font"] = "Font"
L["The font this addon's text uses, over the skin's own. Empty keeps the skin's."] =
    "The font this addon's text uses, over the skin's own. Empty keeps the skin's."
L["Texture"] = "Texture"
L["The texture this addon's bars use, over the skin's own. Empty keeps the skin's."] =
    "The texture this addon's bars use, over the skin's own. Empty keeps the skin's."
L["Skin picker seen"] = "Skin picker seen"
L["Whether the first-run skin picker was closed on this profile."] =
    "Whether the first-run skin picker was closed on this profile."

-- settings/ComposedRows.lua
L["Border"] = "Border"
L["Color by item quality"] = "Color by item quality"
L["Draw each icon's border in its item's quality color (green, blue, purple ...) instead of the swatch. The swatch's alpha still applies; an item whose quality is not known keeps the swatch."] =
    "Draw each icon's border in its item's quality color (green, blue, purple ...) instead of the swatch. The swatch's alpha still applies; an item whose quality is not known keeps the swatch."
L["Draw a border around every item icon: the drop tables, the cards, the toast, the Offer panel and History."] =
    "Draw a border around every item icon: the drop tables, the cards, the toast, the Offer panel and History."
L["The border's texture, from LibSharedMedia. Any border another addon registers shows up here too."] =
    "The border's texture, from LibSharedMedia. Any border another addon registers shows up here too."
L["The border's color. Not read while Use class color is on, except for its opacity, which always applies; nor, for an item whose quality is known, while Color by item quality is on."] =
    "The border's color. Not read while Use class color is on, except for its opacity, which always applies; nor, for an item whose quality is known, while Color by item quality is on."

-- settings/Editors.lua
L["Strength"] = "Strength"
L["Agility"] = "Agility"
L["Intellect"] = "Intellect"
L["Stamina"] = "Stamina"
L["Critical Strike"] = "Critical Strike"
L["Versatility"] = "Versatility"
L["One-handed axes"] = "One-handed axes"
L["One-handed maces"] = "One-handed maces"
L["One-handed swords"] = "One-handed swords"
L["Daggers"] = "Daggers"
L["Fist weapons"] = "Fist weapons"
L["Warglaives"] = "Warglaives"
L["Two-handed axes"] = "Two-handed axes"
L["Two-handed maces"] = "Two-handed maces"
L["Two-handed swords"] = "Two-handed swords"
L["Polearms"] = "Polearms"
L["Staves"] = "Staves"
L["Bows"] = "Bows"
L["Guns"] = "Guns"
L["Crossbows"] = "Crossbows"
L["Wands"] = "Wands"
L["Shields"] = "Shields"
L["The player's name: the looter for an ask, the candidate for an offer."] =
    "The player's name: the looter for an ask, the candidate for an offer."
L["The item's link."] = "The item's link."
L["The item's level."] = "The item's level."
L["The slot the item goes in."] = "The slot the item goes in."
L["The item's upgrade track."] = "The item's upgrade track."
L["The item levels the looter, or the candidate, would gain."] =
    "The item levels the looter, or the candidate, would gain."
L["The item levels you would gain."] = "The item levels you would gain."
L["Ask (whisper to the looter)"] = "Ask (whisper to the looter)"
L["Ask for transmog (whisper to the looter)"] = "Ask for transmog (whisper to the looter)"
L["Ask for off-spec (whisper to the looter)"] = "Ask for off-spec (whisper to the looter)"
L["Offer (whisper to a candidate)"] = "Offer (whisper to a candidate)"
L["Announce (group, raid or instance)"] = "Announce (group, raid or instance)"
L["too long to send"] = "too long to send"
L["unknown tokens, sent as typed: %s"] = "unknown tokens, sent as typed: %s"
L["Preview: %s, to %s"] = "Preview: %s, to %s"
L["To %s: %s"] = "To %s: %s"
L["In force now: %s (%s's own setting)"] = "In force now: %s (%s's own setting)"
L["In force now: %s"] = "In force now: %s"

-- settings/PageEditors.lua
L["What one point of this stat is worth to this specialization. 0 leaves it out."] =
    "What one point of this stat is worth to this specialization. 0 leaves it out."
L["Import a Pawn scale"] = "Import a Pawn scale"
L["Paste a Pawn scale string and press Enter: it replaces this specialization's weights."] =
    "Paste a Pawn scale string and press Enter: it replaces this specialization's weights."
L["Used when Score with is My weights, or Automatic without Pawn: a drop's score is each stat times its weight."] =
    "Used when Score with is My weights, or Automatic without Pawn: a drop's score is each stat times its weight."
L["Never call a drop of this type an upgrade for this specialization."] =
    "Never call a drop of this type an upgrade for this specialization."
L["Ticked types are never called an upgrade for this specialization."] =
    "Ticked types are never called an upgrade for this specialization."
L["Preview"] = "Preview"
L["Tokens"] = "Tokens"
L["Click a token to put it in the message you last edited. Each is filled in when the message is sent."] =
    "Click a token to put it in the message you last edited. Each is filled in when the message is sent."
L["Your messages"] = "Your messages"
L["Reset templates"] = "Reset templates"
L["Put the five messages back to the shipped wording."] = "Put the five messages back to the shipped wording."

-- settings/Pages.lua
L["Comparison"] = "Comparison"
L["Reset the Comparison page's settings (scoring, every spec's weights and unwanted types) to their defaults."] =
    "Reset the Comparison page's settings (scoring, every spec's weights and unwanted types) to their defaults."
L["Messages"] = "Messages"
L["Window"] = "Window"

-- feedback-24: the pages regrouped (Situations, Drops, Comparison, Messages, Window, Alerts)
L["Situations"] = "Situations"
L["Loot rule"] = "Loot rule"
L["Reset the Drops page's settings (situations, quality, items and how long drops are kept) to their defaults."] =
    "Reset the Drops page's settings (situations, quality, items and how long drops are kept) to their defaults."
L["Quality floor"] = "Quality floor"
L["A situation can set a quality of its own: the Quality column on the Situations tab."] =
    "A situation can set a quality of its own: the Quality column on the Situations tab."
L["Items"] = "Items"
L["Item kinds"] = "Item kinds"
L["Retention"] = "Retention"
L["Session"] = "Session"
L["Unwanted types"] = "Unwanted types"
L["Reset the Messages page's settings (sending, auto-ask and templates) to their defaults."] =
    "Reset the Messages page's settings (sending, auto-ask and templates) to their defaults."
L["Offer transmog asks"] = "Offer transmog asks"
L["Also offer an ask on a drop that is no gain for you but whose look you have not collected, with the Ask for transmog template."] =
    "Also offer an ask on a drop that is no gain for you but whose look you have not collected, with the Ask for transmog template."
L["Reset the Window page's settings (layout, columns, starting view and icons) to their defaults."] =
    "Reset the Window page's settings (layout, columns, starting view and icons) to their defaults."
L["Window layout"] = "Window layout"
L["Shown columns"] = "Shown columns"
L["The full layout's Drops table. History shows every column; the compact cards show every fact."] =
    "The full layout's Drops table. History shows every column; the compact cards show every fact."
L["Mark a trade window ending within (seconds)"] = "Mark a trade window ending within (seconds)"
L["Your own drop's Trade window countdown turns to its warning color this many seconds before the item stops being tradeable. 0 turns the mark off."] =
    "Your own drop's Trade window countdown turns to its warning color this many seconds before the item stops being tradeable. 0 turns the mark off."
L["Starting view"] = "Starting view"
L["Content and sort"] = "Content and sort"
L["Alerts"] = "Alerts"
L["Reset the Alerts page's settings (toast and upgrade glow) to their defaults."] =
    "Reset the Alerts page's settings (toast and upgrade glow) to their defaults."
L["Simulator"] = "Simulator"
