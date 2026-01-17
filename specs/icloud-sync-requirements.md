# iCloud同期 仕様（TrainLog）

## 目的
- ログ/種目/設定をiCloudで同期し、複数端末・再インストールでも同じ体験を提供する。
- iCloudが使えない場合もローカル保存で継続利用できる。

## 対象データ
### iCloud保存対象
- トレーニングログ（SwiftData）
  - Workout: id, date, note, sets
  - ExerciseSet: id, exerciseId, weight, reps, durationSeconds, rpe, createdAt
- お気に入り種目ID
- アプリ設定（重量単位など、ユーザーが明示的に変更した値）

### 端末ローカルのみ
- hasSeenTutorial
- 画面の一時状態（タブ選択、検索文字列、表示フィルタ）
- 再計算可能な統計キャッシュ
- バンドル内固定データ（exercises.json など）

## 同期方式（決定: 方式A）
### 採用: 方式A（SwiftDataモデル化してCloudKit同期）
- UserSetting / FavoriteExercise を @Model で追加し、SwiftData経由で同期する。
- 同期経路がSwiftDataに統一されるため、保守が容易。
- FavoriteExercise は `exerciseId` をユニークキーとして扱う。

### 非採用: 方式B（NSUbiquitousKeyValueStore）
- 容量制限や同期遅延があり、同期経路が二重化するため採用しない。

## 設定 / 環境
- XcodeでiCloud（CloudKit）を有効化する。
- CloudKitはprivate databaseのみを使用する。
- コンテナはBundle IDに紐づくものを使用する。
- Apple Developer Program（有料）加入が前提。Personal TeamではiCloud Capabilityを使用できない。
- App IDでiCloud Capabilityを有効化し、CloudKitコンテナを作成する。

## iCloud状態判定
- CKContainer.accountStatus で判定。
- available / noAccount / restricted / couldNotDetermine を扱う。

## iCloud同期状態の可視化（UI）
- Settingsに「iCloud同期」セクションを追加。
- 表示例:
  - 同期済み / 同期中
  - iCloud未設定
  - iCloud容量不足
  - オフライン / 一時的な同期失敗
- iCloud未保存時の警告:
  - 「この端末内にのみ保存されています。アプリ削除や機種変更でデータが消えます。」
- iCloud設定への導線（設定アプリを開く）を用意する。
- 可能なら「最終同期時刻」を表示（取得できる場合のみ）。
- アプリ内にiCloud同期のON/OFFトグルは設けない。
- 容量不足の表示はCloudKitエラー検知が必要なため、初期実装では表示できない可能性がある。

## 同期フロー
### 初回起動（iCloud有効）
- CloudKitストアを生成し同期開始。
- 既存ローカルデータがある場合はiCloudへ1回だけ移行（破棄しない）。
- iCloud側に既存データがある場合は、id基準でマージする。
- 移行件数と失敗はログに残す。

### iCloud無効/未サインイン
- ローカルストアで動作。
- iCloud未保存の警告を表示。

### iCloud復帰/再有効化
- ローカルデータをiCloudにマージ。
- 同期完了までUIはブロックしない。

### 端末追加・再インストール
- iCloud上のデータを自動復元。

### アカウント切替
- 旧アカウントのデータと混在させない。
- 必要ならローカルに隔離する。

## 競合・整合性
- idを永続キーとして扱い重複作成を防ぐ。
- 競合はlast-write-wins（自動解決）。
- 競合選択UIは用意しない。
- 削除は全端末に伝播する。

## エラー対応
- notAuthenticated / quotaExceeded / networkUnavailable / serviceUnavailable / requestRateLimited 等を想定。
- ユーザー向けの分かりやすい説明と対処導線（設定を開く、再試行）。
- 同期失敗時もアプリ操作は継続可能。
- 読み込み失敗時にストア削除は行わない（明示的に破棄宣言がある場合のみ）。

## データエクスポート（将来機能）
- 目的: 端末変更・障害時のバックアップと共有。
- エクスポートはiCloud状態に依存せず、現在使用中のストア内容を対象にする。
- 同期中の場合は「同期中のため最新でない可能性」を表示する。
- フォーマット: JSON（UTF-8、schemaVersion付き）。
- 例（概略）:
  - schemaVersion: Int
  - exportedAt: ISO 8601
  - appVersion / locale / timezone
  - workouts: [{ id, date, note, sets: [...] }]
  - favorites: [exerciseId]
  - settings: { weightUnit }
- ファイル名例: `trainlog_export_yyyyMMdd_HHmm.json`
- ShareSheetでユーザーが保存先を選択（Files等）。
- インポートは別仕様として切り出す（本仕様には含めない）。

## 移行・バックアップ
- iCloud導入前の既存ユーザーはローカル→iCloud移行を必須とする。
- 破壊的変更前にエクスポート機能でバックアップ取得を推奨する。

## 法務 / ポリシー
- iCloud同期の利用とエクスポート機能をプライバシーポリシー/利用規約に明記する。

## 非機能要件
- iOS 17以上。
- オフライン動作可能。
- 起動時間・UIレスポンスへの悪影響を避ける。

## テスト観点
- iCloud ON/OFF 切替
- 初回起動 → 再インストール → 復元
- 2台間の同時編集・削除
- アカウント切替
- 容量不足 / ネットワーク断
- 既存ローカルデータの移行
- エクスポートの内容確認と再現性

## 受け入れ基準
- iCloud有効時、ログ/お気に入り/設定が複数端末で一致する。
- 再インストール後もiCloud上のデータが復元される。
- iCloud無効/容量不足時はローカル保存で動作し、注意文が表示される。
- エクスポートがiCloud状態に関係なく実行できる。
