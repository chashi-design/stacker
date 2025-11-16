# Code Review

## 1. Model context never saved after inserting a workout
- **Location:** `TrainLog/ContentView.swift` lines 341-432
- **Issue:** `saveWorkout()` builds a `Workout` object and calls `context.insert(workout)` but never invokes `try context.save()`. SwiftData does not automatically flush inserts immediately, so the log entry may disappear when the app is backgrounded or terminated before the next autosave.
- **Suggestion:** Call `try? context.save()` (or handle the thrown error properly) right after the insert so that the transaction is durably persisted and the History / Stats queries can see the change immediately.

## 2. Normalizing to midnight with `Calendar.current` causes “day” drift across time zones
- **Location:** `TrainLog/ContentView.swift` lines 263-294 & 421-424, `TrainLog/LogDateHelper.swift` lines 11-16, `TrainLog/ContentView.swift` lines 198-214
- **Issue:** The selected log date is normalized with `Calendar.current.startOfDay(for:)` and stored as a `Date`. That value is an absolute timestamp (e.g., 2024-05-01 00:00 JST == 2024-04-30 15:00 UTC). If the user later opens the app in a different time zone, `LogDateHelper.label` and `StatsView.aggregateVolume` use the *current* `Calendar.current`, so the same stored timestamp can fall on the previous/next local day and appears under the wrong calendar bucket.
- **Suggestion:** Persist the workout’s “calendar day” independent of the device time zone (e.g., store `DateComponents(year:month:day:)`, or normalize using a fixed UTC calendar and render labels with that same calendar). At minimum, use a single `Calendar` / `TimeZone` value throughout normalization, display, and aggregation so that dates do not shift when the system time zone changes.

## 3. `aggregateVolume` runs twice per render
- **Location:** `TrainLog/ContentView.swift` lines 165-191
- **Issue:** Both the chart section and the textual list call `aggregateVolume(range:)`, each re-scanning every `Workout`. With a non-trivial history this doubles the amount of aggregation work performed on every body refresh.
- **Suggestion:** Compute the totals once per render (e.g., `let totals = aggregateVolume(range: selectedRange)` at the start of `List`) and reuse the cached array in both sections. That keeps the `O(n)` aggregation cost to a single pass per update.
