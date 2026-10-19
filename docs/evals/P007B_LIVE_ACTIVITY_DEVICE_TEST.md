# P007B — Live Activity / Dynamic Island Device Test

## State today
- The real `ActivityConfiguration` + Dynamic Island regions compile and ship inside the running extension on device.
- BUT the **app does not yet start a Live Activity** (`Activity.request` is not wired into any app UI), and the app's
  `GuardianActivityAttributes` is still a **separate type** from the extension's (unification = P007B §2, NOT done —
  see Known Limitations). A Live Activity only renders when the app starts an Activity whose attributes type matches the
  widget's. So there is **nothing to render on device yet**.
- Ordering/stale/identity safety (A→B→delayed-A, staleDate, Guardian OFF) is proven at the logic layer
  (`GlyphSurfaceController` / `LiveActivityUpdatePolicy`, headless tests), not yet on a live device activity.

## Requires (before a real device Live Activity test)
1. Unify `GuardianActivityAttributes` into one shared type (app + extension). 2. Wire `Activity.request`/`update`/`end`
   into the app. 3. On this team, Live Activity push updates + App-Group-shared content need a paid membership for full
   function (local Live Activities may start, but the shared-state architecture is App-Group-gated here).

## Status
`NATIVE_SURFACE_COMPILED_AND_SHIPPED_ON_DEVICE; LIVE_RENDER_NOT_YET_EXERCISED (app does not start an Activity; attributes not unified)`.
