# Hotwire + Action Cable 学習計画

## 現状の問題

最初に Turbo Streams + Action Cable を**同時に**使ったチャットアプリを作ったが、仕組みが理解できなかった。

### 理解できなかった理由

1. **Turbo Streams 単体の動作を理解していない**
   - 「サーバーから HTML の指示書を送る」という概念が曖昧
   - `turbo_stream.append` が何をしているのかわからない

2. **Action Cable 単体の動作を理解していない**
   - WebSocket が何なのかわからない
   - 「購読」「配信」の概念が曖昧

3. **2つを同時に学ぼうとした**
   - `broadcasts_to :room` が内部で何をしているか見えない
   - `turbo_stream_from @room` が何をしているかわからない
   - 組み合わせの魔法が多すぎて、個々の動作が見えない

---

## 新しい学習計画

### Step A: Turbo Streams 単体を体験する（Action Cable なし）

**目的:** 「サーバーから HTML の指示書を送って、ページの一部を更新する」を理解する

**やること:**
1. `broadcasts_to :room` を一旦コメントアウト
2. `turbo_stream_from @room` を一旦コメントアウト
3. `app/views/messages/create.turbo_stream.haml` を作成
4. メッセージ送信 → **自分の画面だけ**更新されることを確認
5. 別のブラウザで開いた画面は更新**されない**ことを確認

**学べること:**
- Turbo Streams は「DOM 操作の指示書」である
- HTTP レスポンスとして返すと、送信者の画面だけ更新される
- 他の人に届けるには別の仕組み（Action Cable）が必要

### Step B: Action Cable 単体を体験する（Turbo Streams なし）

**目的:** 「WebSocket でリアルタイム双方向通信する」を理解する

**やること:**
1. 簡単なチャンネルを自分で作る
2. JavaScript でメッセージを受信してコンソールに表示
3. サーバーから手動でブロードキャストしてみる

**学べること:**
- WebSocket は「常時接続の双方向通信」である
- Action Cable はその Rails 用フレームワーク
- チャンネル = 通信の部屋、購読 = 部屋に入る、配信 = 部屋全体に送る

### Step C: 両方を組み合わせる

**目的:** 「Action Cable で Turbo Streams を送る」を理解する

**やること:**
1. `turbo_stream_from @room` を復活
2. `broadcasts_to :room` を復活
3. 2つのブラウザで開いて、リアルタイム同期を確認

**学べること:**
- `turbo_stream_from` = Action Cable で購読を開始
- `broadcasts_to` = Action Cable で Turbo Streams を配信
- 両方組み合わせると「全員の画面がリアルタイム更新」される

---

## 現在のコード状態

### 完成しているもの（動作する）

- Room モデル（`has_many :messages`）
- Message モデル（`belongs_to :room`, `broadcasts_to :room`）
- RoomsController（`index`, `show`）
- MessagesController（`create`）
- ビュー（`rooms/index`, `rooms/show`, `messages/_message`, `messages/_form`）
- ルーティング
- シードデータ（「一般」「雑談」ルーム）
- Tailwind CSS でのスタイリング

### 次回作成するもの

- `app/views/messages/create.turbo_stream.haml`（Step A 用）

---

## 次回の再開手順

1. このファイルを読む
2. Step A から始める
3. `app/models/message.rb` の `broadcasts_to :room` をコメントアウト
4. `app/views/rooms/show.html.haml` の `turbo_stream_from @room` をコメントアウト
5. `app/views/messages/create.turbo_stream.haml` を作成
6. サーバーを起動して動作確認

---

## 参考：フローの全体像（理解できたら振り返る用）

```
1. ユーザーがチャット画面にアクセス
2. turbo_stream_from @room で WebSocket 接続確立 ← Step B で理解
3. フォームに入力して送信
4. Turbo がフォーム送信を横取り、非同期 POST ← Step A で理解
5. MessagesController#create 実行
6. Message が DB に保存
7. broadcasts_to :room で Turbo Stream 生成 ← Step A で理解
8. Action Cable で全員に配信 ← Step B で理解
9. 各ブラウザが Turbo Stream を受信
10. DOM が自動更新される ← Step A で理解
```

---

## 疑問リスト（学習しながら解消する）

- [ ] Turbo Stream って何？
- [ ] なぜフォーム送信を「横取り」するの？
- [ ] WebSocket って何？HTTP と何が違う？
- [ ] Action Cable って何？
- [ ] `broadcasts_to :room` は内部で何をしてる？
- [ ] `turbo_stream_from @room` は内部で何をしてる？
