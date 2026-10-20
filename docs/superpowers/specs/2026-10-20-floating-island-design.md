# Floating Island Design

## Goal

Provide an optional, low-footprint resting state for Codex Quota Rings. The widget should remain recognisable and useful while occupying minimal desktop space, then restore the user's selected layout when the pointer reaches it.

## Interaction

- The default is off, preserving current hover-to-detail behavior.
- When enabled, both the compact widget and large card begin as a 54 × 54 point density-scaled island.
- The island contains the same two quota rings. Concentric-ring preference is respected.
- Hovering expands the current size and layout with a native window frame animation.
- Leaving the expanded widget starts a 550 ms collapse delay. Entering again cancels the delay.
- A click on a collapsed island expands it. A click on the restored widget opens the existing details surface.
- Right-click menus and drag-to-move continue to work in both states.
- Opening details always restores the widget first; it cannot collapse while details are open.

## Visual language

The island uses the existing dark card surface, border, ring palette, low-quota contrast treatment, star trails, and reset emphasis. It does not add text labels, keeping the surface compact. Stale data is still marked by the existing warm status dot.

## Persistence and safety

`widget.floatingIslandEnabled` is persisted in `UserDefaults`. The island changes only the active window frame; size, compact orientation, visibility choice, position, quota polling, history, and privacy behavior are unchanged.
