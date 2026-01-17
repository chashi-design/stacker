# iCloud Sync Design (TrainLog)

## Goals
- Sync logs, favorites, and settings via CloudKit (private database).
- Keep the app usable with local-only storage when iCloud is unavailable.
- Visualize iCloud sync status in Settings (no in-app toggle).
- Prepare for future export feature without blocking iCloud sync.

## Data Model (SwiftData)
### Existing
- Workout (unchanged)
- ExerciseSet (unchanged)

### New (Method A)
#### UserSettings (singleton)
- Purpose: store app-wide settings for sync.
- Fields:
  - id: String (unique, fixed "singleton")
  - weightUnitRaw: String (WeightUnit.rawValue)
  - updatedAt: Date
- Rules:
  - Exactly one record should exist.
  - If multiple are found, keep the newest updatedAt and remove the rest.

#### FavoriteExercise
- Purpose: store favorite exercise selections.
- Fields:
  - exerciseId: String (unique, exercises.json id)
  - createdAt: Date
- Rules:
  - One record per exerciseId.
  - Remove the record to "unfavorite".

Notes:
- Use @Attribute(.unique) for id/exerciseId.
- Add optional fields later for new settings to avoid destructive migration.

### SwiftData schema sketch (non-final)
```swift
@Model
final class UserSettings {
    @Attribute(.unique) var id: String
    var weightUnitRaw: String
    var updatedAt: Date
}

@Model
final class FavoriteExercise {
    @Attribute(.unique) var exerciseId: String
    var createdAt: Date
}
```

### Model access rules
- Use SettingsStore (ObservableObject) to read/update UserSettings via ModelContext.
- Use FavoriteExerciseStore (ObservableObject) for isFavorite/toggle/update.
- Always call context.save() after writes.
- If legacy storage still exists during rollout, one-time migrate and then stop writing to legacy keys.

## Store and Container Strategy
- Create a ModelContainerProvider that chooses the active store at launch.
  - If CKContainer.accountStatus == available: use CloudKit-backed configuration.
  - Otherwise: use local configuration.
- Use distinct store URLs:
  - Local: TrainLog.store
  - Cloud: TrainLogCloud.store
- Expose active ModelContainer and SyncState via environment.

### Provider responsibilities
- Determine iCloud availability at launch (async accountStatus).
- Build appropriate ModelConfiguration:
  - Local: `ModelConfiguration(schema: url:)`
  - Cloud: `ModelConfiguration(schema: cloudKitContainerIdentifier: url:)`
- Provide a fallback path when Cloud configuration fails.
- Publish the active store type: `.cloud` or `.local`.

### Launch flow (proposed)
1. Check CKContainer accountStatus.
2. If available:
   - Try to initialize CloudKit-backed store.
   - On failure, fallback to local and set syncState = error/localOnly.
3. If not available:
   - Initialize local store and set syncState = localOnly.

### App restart requirement
- When accountStatus changes to available after launch:
  - Show a banner in Settings: "iCloudが有効になりました。再起動すると同期が有効になります。"
  - Do not hot-switch stores in-process (risk of state corruption).

### Store URLs
- Use Application Support directory.
- Keep separate filenames for local and cloud stores to avoid collisions.
- Never delete existing stores automatically.

### Migration trigger
- If cloud becomes active and cloudMigrationDone is false:
  - Run Local -> Cloud migration once.
  - Mark migration completion in UserDefaults.

### CloudKit environment
- ICLOUD_ENVIRONMENT = Development (Debug) / Production (Release) を使用する。
- DevelopmentとProductionでデータは分離される。

## Migration Plan
### Local -> iCloud (first launch with iCloud available)
- Load local store if it exists.
- Create cloud store.
- Copy local records (Workout, ExerciseSet, FavoriteExercise, UserSettings) into cloud store.
- Mark migration complete in local-only UserDefaults (e.g., cloudMigrationDone = true).
- Do not delete local store automatically.

### Favorites / Settings migration
- On first launch after update:
  - If UserSettings is empty, read legacy AppStorage values and insert.
  - If FavoriteExercise is empty, read legacy UserDefaults favorites and insert.
- Keep hasSeenTutorial as local-only AppStorage.

### iCloud unavailable at launch
- Use local store and show warning.
- When account becomes available, prompt user to restart to switch stores.

## Sync Status Monitoring (Best-effort)
### State model
- ICloudSyncState
  - availability: available / noAccount / restricted / unknown
  - network: online / offline
  - status: synced / syncing / error / localOnly
  - lastLocalSaveAt: Date?
  - lastError: ErrorKind?

### Update triggers
- App launch
- scenePhase == active
- CKAccountChanged notification
- Network path changes

### Notes
- SwiftData does not expose detailed CloudKit sync events.
- Status is coarse and best-effort; clarify in UI.
- accountStatus中心のため、容量不足や実際の同期完了は直接検知できない。
- 「最終同期」は最終チェック時刻であり、実際の同期完了時刻ではない。

## UI Integration (Settings)
- Add "iCloud Sync" section with:
  - Current status label
  - Optional lastLocalSaveAt
  - Warning when local-only
  - Action to open system Settings (iCloud)
- No in-app toggle for iCloud sync.

### UI layout (Settings > iCloud Sync section)
- Row 1: Status summary (non-tappable)
  - Title: "iCloud同期" / "iCloud Sync"
  - Value: status text (Synced / Syncing / Local only / Error)
  - Icon: "icloud" (optional)
- Row 2: Detail message (non-tappable)
  - Footnote style, multi-line.
  - Shows warning and short guidance when local-only or error.
- Row 3: Last sync (optional, non-tappable)
  - Title: "最終同期" / "Last Sync"
  - Value: formatted timestamp when available.
- Row 4: Action (tappable)
  - Title: "設定を開く" / "Open Settings"
  - Opens app's Settings page.
  - Note: iOS does not allow deep-link to iCloud settings; copy should mention checking iCloud in system settings.

### Status mapping (strings)
- Synced:
  - "同期済み" / "Synced"
  - Detail: none or "iCloudに保存されています。" / "Saved to iCloud."
- Syncing:
  - "同期中..." / "Syncing..."
  - Detail: "最新になるまで少し時間がかかる場合があります。" / "It may take a moment to finish."
- Local only (noAccount / restricted):
  - "iCloud未設定" / "iCloud not available"
  - Detail (required):
    - "この端末内にのみ保存されています。アプリ削除や機種変更でデータが消えます。"
    - "Data is stored only on this device. Uninstalling or switching devices will lose data."
- Error (quota / network / service):
  - "同期エラー" / "Sync error"
  - Detail: error-specific guidance + retry suggestion.

### Haptic / interaction rules
- The action row must trigger haptic feedback and navigate in the same tap.
- Use full-width tap target (`frame(maxWidth: .infinity, alignment: .leading)` +
  `contentShape(Rectangle())`).
- Non-tappable rows must not trigger feedback.

## Favorites and Settings Data Flow
- Replace ExerciseFavoritesStore persistence with SwiftData-backed store:
  - FavoriteExerciseStore (ObservableObject)
  - Uses ModelContext for CRUD
- Replace @AppStorage weightUnit with UserSettings (SwiftData).
- Keep @AppStorage("hasSeenTutorial") local-only.

### Behavior notes
- Weight values are stored in kg in ExerciseSet and never rewritten when the unit changes.
- Changing the unit affects display/input only; existing logs are shown in the new unit via conversion.
- Re-saving a set after switching units may introduce small rounding differences.
- Favoriting inserts a FavoriteExercise record; unfavoriting deletes it.
- Favorite deletions sync to all devices (offline changes sync later; last-write-wins).

## Export Integration (Future)
- ExportService reads from the active store (cloud or local).
- Output JSON with schemaVersion and metadata.
- Show "may be stale" banner if status is syncing or offline.

## Error Handling
- If CloudKit store creation fails, fallback to local and show message.
- Map common errors (notAuthenticated, quotaExceeded, networkUnavailable, serviceUnavailable)
  to user-friendly copy.
- Do not delete stores unless data wipe is explicitly declared.

## Testing / Validation
- iCloud on/off at launch
- Reinstall and restore from iCloud
- Two-device edits and deletions
- Account sign-out / sign-in
- Network loss and quota exceeded
- Migration from legacy favorites/settings
- Export while syncing and offline

## Limitations
- Sync status is best-effort due to SwiftData limitations.
- Store switch requires app restart when account status changes.
