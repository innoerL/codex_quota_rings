# Floating Island Implementation Plan

1. Add a persisted `floatingIslandEnabled` preference and menu toggle.
2. Add density-scaled island metrics and an island draw path shared by compact and large widgets.
3. Route widget pointer events through the app controller so island expansion and delayed collapse do not conflict with detail hover state.
4. Restore the full widget before presenting details and cancel pending collapse while details are visible.
5. Cover preference persistence, menu selection, layout sizes, rendering, compilation, and bilingual documentation.
