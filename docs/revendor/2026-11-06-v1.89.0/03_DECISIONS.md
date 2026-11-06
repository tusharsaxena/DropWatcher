# Decisions

No interview: the owner decided upfront for the whole run. Source: `Ka0sAddonsCommonTasks/docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/00_PLAN.md`, *Decisions (owner, 2026-11-06, asked upfront)*.

- **Widgets 23 cascade for the compact Filters ▾ (class B):** **adopt, implemented in item V89A-DW.** Not implemented in this item.
- **`LibKa0s-IconBrowser-1.0` (class C):** settled. This addon has no icon chooser. Recorded here, **no issue** (owner ruling).
- **Toast 4 stack:** already adopted (`DW-T2`, `a50f465`). Nothing to decide.
- **Widgets 23 rows for the History row menu (`modules/WindowHistory.lua:328`):** **undecided.** The plan's table does not name it. Recommendation: *not now*, because the menu has one flat entry, so the cascade fields add nothing, and moving it off `MenuUtil` is a skinning change in its own right. Reported to the run's lead. Not implemented and not filed.

No GitHub issue was created in this item. Class A (kit 51) arrived with the copy.
