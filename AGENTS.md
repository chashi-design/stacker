# AGENTS.md – TrainLog iOS App (SwiftUI)

## Mission / Goal
- このリポジトリでは **トレーニングログを記録・閲覧・分析できる iOS アプリ**を開発する。
- 目的: 入力のしやすさ・履歴管理のしやすさ・統計のわかりやすさを重視したアプリ体験を実現する。
- 対象OS: iOS 17 以上。

---

## Tech Stack & Constraints
- 言語: **Swift 5.x**
- UI: **SwiftUI**（UIKit を新規作成することは禁止）
- 永続化: **SwiftData**
- 構造: **MVVM 準拠**
- iOS 17 以上前提のため、SwiftUIの `sensoryFeedback` など iOS 17 API を利用してよい
  - View = 表示・入力
  - ViewModel = ビジネスロジック / 状態管理
  - Model = SwiftData データモデル

---

## Project Structure（※このプロジェクト実際の構造に合わせる）
- `/TrainLog/` … アプリ本体
  - `ContentView.swift`
  - `WorkoutListView.swift`
  - `LogDateHelper.swift`
  - `SearchEngine.swift`
  - `Models.swift`
- `/TrainLogTests/` … テスト
- `.xcodeproj` / `.xcworkspace` … プロジェクト構成

---

## Coding Style
- 型名: **PascalCase**
- 変数・関数名: **camelCase**
- コメント: 日本語で OK
- SwiftUI ファイルは `#Preview` をできるだけ用意
- 1 ファイルが 300 行超えたら分割を検討
- segmented control は必ず触覚FBを付与し、共通の `segmentedHaptic` を利用する

## ファイル分割の粒度
- 画面単位でファイル分割する（例: 1画面1ファイル）。
- サブ画面/詳細画面は別ファイルに切り出す（例: 週ごとの一覧/詳細など）。
- 共通部品・小さなViewは `Components/` か同一ディレクトリ内に `*View.swift` として切り出す。
- 1ファイル内に複数画面が混在した場合は分割を優先する。

---

## Architecture Guidelines
- View はロジックを持たず、UI・状態反映に専念する
- ビジネスロジックは ViewModel に置く
- SwiftData モデル変更時は後方互換性を常に意識する
- モーダルや複雑 UI はコンポーネントとして分離する（PickerView / SetEditorView など）

---

## Agent Workflow（Codex が「作業中に守るべきルール」）
1. **まず変更予定のファイル一覧を提示すること**
2. 作業は **小さなステップ**に分割すること  
   （大規模変更を一度に行わない）
3. 各ステップの前に **意図と処理内容を説明**すること
4. 必ず **diff を提示してから**適用すること
5. 依存ファイルがありそうな場合は確認してから触ること
6. SwiftUI の Navigation / State / Binding を壊さないよう注意すること
7. SwiftData の保存ロジックは `context.save()` を必ず確認すること

---

## What the Agent Should Prioritize（特に重要）
- **ログ画面（入力UI）の改善**
- **SearchEngine.swift の検索・サジェスト改善**
- **SwiftData モデルの整合性チェック**
- **統計画面の正確な集計**
- **UI/UX 改善提案（過剰な変更は禁止）**

---

## Please Avoid
- サードパーティライブラリを無断で導入すること
- 既存コードの「全面書き換え」を提案すること
- Project 設定の大規模変更
- 名前変更やファイル移動を突然行うこと
- MVVM を壊す実装

---

## Haptic / Feedback Rules
- リストの行タップは「どこをタップしても遷移＋触覚FB」が必ず発火すること
- リスト外を含むリンク（NavigationLink など）も、遷移と触覚FBが必ず同期して発火すること
- NavigationLink には、必要に応じて selection/binding を使い、遷移と触覚を同一イベントで同期させる
- 行ラベルは全幅タップを保証するために `frame(maxWidth: .infinity, alignment: .leading)` と `contentShape(Rectangle())` を基本とする
- 「行内のテキストだけ反応」「余白だけ反応」といった分断挙動は許可しない
- 非遷移の行タップ（詳細開閉など）は別途ルールを定義してから導入する
- 例外: カレンダーの日付タップは非遷移でも触覚FBを許可する
- 触覚FBは「選択状態の変化」で発火させ、行ごとに `sensoryFeedback` を付けない（複数発火を防ぐ）
- `if/else` の分岐に `onChange`/`sensoryFeedback` を付ける場合は `Group` で包み、同一Viewに修飾子を適用する
- 触覚FBの強度は原則 `.light` を使う（例外が必要なら事前に相談）

---

## When to Ask the User
- SwiftData モデルのフィールド追加/削除
- 画面遷移方法を変える場合（sheet → navigation など）
- UI が大きく変わる場合（特にログ入力UI）
- 関連ファイルを大幅に増やす場合

---

## Roadmap
### v0.1
- 種目一覧
- ログ入力（シンプル）
- 履歴表示
- ローカル保存（SwiftData）

### v0.2（現在ここ）
- 入力UIの大幅改善（モーダル式）
- 統計画面の強化
- SearchEngine の賢さ改善

### v1.0
- iCloud 同期
- UI polished / エラー処理強化
- TestFlight
