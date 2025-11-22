# AGENTS.md – iOS App (SwiftUI)

## Mission / Goal
- このリポジトリでは iOS アプリを開発する。
- 目的: ユーザーのトレーニングログを簡単に記録・閲覧・分析できるアプリを作る。
- 対象OS: iOS 17 以上。


## Tech Stack & Constraints
- 言語: Swift 5.x
- UI: SwiftUI （Storyboard / UIKit ベースの画面は原則追加しない）
- データ永続化: SwiftData（必要に応じて拡張）
- アーキテクチャ: MVVM ベース
  - View: SwiftUI View
  - ViewModel: ObservableObject / @StateObject / @EnvironmentObject
  - Model: データ構造 / SwiftData モデル
- サードパーティライブラリ:
  - 追加する場合は必ず提案と理由を示し、ユーザーに確認してからにする。
  
  ## Project Structure
- Xcode プロジェクト: `YourAppName.xcodeproj`
- アプリソースコード: `YourAppName/` ディレクトリ配下
  - `Views/`        … 画面（SwiftUI View）
  - `ViewModels/`   … ViewModel
  - `Models/`       … データモデル（SwiftDataを含む）
  - `Services/`     … データ保存やAPIなどのサービス層
  - `Resources/`    … Asset, Strings など
  
  ### ビルド・テスト
- 通常ビルド: Xcode でターゲット `YourAppName` を選択して Run
- コマンドライン（あれば）:
  - `xcodebuild -scheme YourAppName -destination 'platform=iOS Simulator,name=iPhone 16'`

テストやビルド方法を変更した場合は、このセクションを更新してほしい。


## Code Style
- 型名（struct / class / enum / protocol）: PascalCase  
  - 例: `WorkoutSessionViewModel`, `ExerciseDetailView`
- 変数・関数名: camelCase  
  - 例: `loadWorkouts()`, `selectedExercise`
- コメント: 基本日本語で、丁寧に記載 
- 1ファイルが 300 行を超える場合は、責務に応じて分割を検討する。
- SwiftUI View は可能ならプレビュー用の `#Preview` を用意する。

## Architecture Guidelines
- 画面ごとに View + ViewModel をセットで用意する:
  - 例: `WorkoutListView` と `WorkoutListViewModel`
- View はできるだけロジックを持たず、状態管理と表示に集中させる。
- ビジネスロジックやデータ取得は ViewModel / Service に置く。

## Roadmap（例なので適宜編集）
### v0.1 (MVP)
- 種目の選択
- 体重/回数/セット数の入力
- トレーニング履歴一覧
- ローカル保存（SwiftData）

### v0.2
- 統計画面（グラフ）
- 種目検索/サジェストの改善

### v1.0
- iCloud 同期
- UI 調整・エラー処理・TestFlight 配布準備

## What the Agent Should Prioritize
- 既存の SwiftUI コードのリファクタリング（責務分離、命名改善）
- 新しい画面を追加する場合は、まず View + ViewModel の雛形提案から始める
- 検索ロジックや SwiftData モデル設計の改善提案
- ビルドエラーや SwfitUI のコンパイルエラーが出た場合の修正

## Git Workflow
- メインブランチ: `main`
- 新機能: `feature/...` ブランチを作成して作業する。
- コミットメッセージ:
  - 英語で要約（例: `Add workout history list view`）

## Please Avoid
- サードパーティライブラリの追加を、ユーザーに相談なく行うこと。
- 既存コードの大規模削除や全面書き換えを、理由なく提案すること。
- Xcode プロジェクト設定の大きな変更（Bundle ID 変更など）を黙って行うこと。

## When to Ask the User
- データモデルを後方互換性を壊す形で変更する場合
- 画面のUI/UXで選択肢が複数ある場合
- 新しいライブラリ導入を検討する場合

