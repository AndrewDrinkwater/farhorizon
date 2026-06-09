# ADR 0028 — Direct course plotting + drag-to-route

**Status:** accepted · **Date:** 2026-06-09
**Builds on / amends:** ADR 0014 (order lifecycle), ADR 0020 (nav targets &
waypoints), ADR 0027 (course obstacle routing). **Supersedes** the waypoint-by-
empty-click compose flow (ADR 0027) and the no-go *Lay-In reject* (ADR 0027).

## Context
Composing a route by clicking empty space to drop waypoints, with a no-go simply
blocking Lay In, was clumsy: nothing showed until you laid in, and you couldn't
see *why* a leg was blocked or fix it directly. The captain wants to see the
course the instant a target is picked and bend it by hand around obstacles.

## Decision

**Plot on select (direct).** Selecting a target (body / contact / empty point)
immediately plots a **direct** course — ship → target — shown on both nav views.
The order *lifecycle* is unchanged (ADR 0014): **Lay In Course** still issues the
order and **Engage** still flies it. The plot is the live compose route; Lay In
and Engage both (re)issue `set_course` from it, so what flies is always the plot.

**No-go paints red, blocks Engage (not Lay In).** A course leg crossing a `nogo`
zone draws **red**; a `hazard` leg draws **amber**; clear is the accent colour.
Lay In is always allowed; **Engage is disabled while any leg crosses a no-go**
(`Travel.available` `engage` gated on `route_nogo`; `FlightController._engage`
rejects with `ORDER_REJECT_OBSTRUCTION` as the authority). Hazards only warn. The
view colours the line from `Zones.route_block` (the pure level), so red == "drag
me clear before you can go."

**Grab the course to add a waypoint, drag to route.** Pressing on the plotted
line (not on a body) **inserts a waypoint** at that point on the nearest leg and
begins dragging it; pressing on an existing waypoint handle drags that one;
release commits. This replaces empty-click-adds-waypoint (an empty click with no
plot still sets a free-point destination, ADR 0020). The view owns the gesture
(it has the screen↔real mapping incl. orrery warp + zoom/pan) and pushes the
resulting waypoint list to the Helm via `nav_waypoints_set`; the Helm re-emits the
route. Editable only while **not under way**.

**Clear Course removes the plot entirely.** Clears the selection + waypoints and
drops a not-engaged `current_order` (a new `clear_course` order); the views clear
their plot. (Under way, the captain uses Belay / All Stop.)

## Consequences
- `FlightController`: `_set_course` no longer rejects no-go; `_engage` does (and
  Travel gates the button). New `clear_course` order (drop course when idle).
- New `EventBus.nav_waypoints_set(waypoints)`; Helm owns `_route_waypoints`,
  re-emits `nav_route_changed`. `Engage`/`Lay In` (re)issue from the compose route.
- Views: colour the plotted route by `Zones.route_block`; draggable waypoint
  handles; insert-on-grab. The plotted (compose) route renders when idle; the
  engaged `current_order` route renders under way.
- `Travel.available`: `route_nogo` moves from `lay_in` to `engage`.

## Alternatives rejected
- **Keep empty-click waypoints** — less direct than grabbing the line you can see;
  the drag gesture is the point.
- **No-go blocks Lay In** (ADR 0027 original) — you couldn't see/fix the route;
  painting red + blocking Engage lets the captain drag it clear.
- **Auto-engage on plot** — removes the deliberate execute beat (ADR 0014).
