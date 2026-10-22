-- tests/prose_waivers.lua — what the kit's US-English gate MUST NOT correct here.
--
-- Read by `tests/_kit/test_prose.lua` (localization-§5). Per FILE and per WORD, never per file
-- alone: a whole-file waiver hides every OTHER British spelling in a file this repository edits
-- often. The two files below are waived for `minimis` and for nothing else, so a `colour` that lands
-- in either still reddens.
--
-- This addon's own spelling is `minimize` everywhere it owns the word: the window's
-- `SetMinimized`, the `window.minimized` path, the locale keys and the prose. What is left below is
-- spelling this repository does not own.

return {
    waived = {
        -- A LIBRARY'S FIELD NAME. LibKa0s-Media-1.0 ships the title-bar mark as
        -- `libs/LibKa0s/media/icons/minimise.tga` and catalogs it under `minimise`; NS.Icon looks
        -- it up by that key, and a respelling answers nil and draws the fallback character.
        ["modules/WindowTitleBar.lua"] = { minimis = true },
        -- The same catalog name in the `LibKa0s icons:` declaration under the provenance line
        -- (library-stack-§7): the kit's parser and tools/prune-icons.lua match it against the
        -- catalog, so `minimize` there is an unknown name and the prune refuses it.
        ["CLAUDE.md"] = { minimis = true },
    },
}
