# Hotwire (Turbo Streams) + Action Cable 完全ガイド

このドキュメントでは、リアルタイムチャット機能の仕組みを初学者向けに解説します。

---

## 目次

1. [従来のWebアプリとの違い](#1-従来のwebアプリとの違い)
2. [Hotwire とは何か](#2-hotwire-とは何か)
3. [Action Cable とは何か](#3-action-cable-とは何か)
4. [Turbo Streams の仕組み](#4-turbo-streams-の仕組み)
5. [このチャットアプリの動作フロー](#5-このチャットアプリの動作フロー)
6. [コード解説](#6-コード解説)
7. [よくある疑問](#7-よくある疑問)

---

## 1. 従来のWebアプリとの違い

### 従来の Web アプリ（リクエスト・レスポンス型）

```
[ブラウザ] --リクエスト--> [サーバー]
[ブラウザ] <--HTML-------- [サーバー]
[ページ全体が再読み込み]
```

**問題点:**
- ユーザーがアクションを起こさないと更新されない
- 他のユーザーの変更をリアルタイムで知ることができない
- チャットアプリでは、相手のメッセージを見るために「更新ボタン」を押す必要がある

### SPA（React, Vue など）

```
[ブラウザ] --API リクエスト--> [サーバー]
[ブラウザ] <--JSON------------ [サーバー]
[JavaScript で DOM を構築]
```

**問題点:**
- フロントエンドとバックエンドで2つのアプリを作る必要がある
- JavaScript のコード量が膨大になる
- 状態管理が複雑

### Hotwire + Action Cable（このアプリ）

```
[ブラウザ] <=====WebSocket=====> [サーバー]
           （常時接続・双方向通信）

サーバーから HTML を直接送って DOM を更新
```

**メリット:**
- JavaScript をほとんど書かなくていい
- サーバーサイドで全て完結
- リアルタイム更新が簡単に実現できる

---

## 2. Hotwire とは何か

**Hotwire = HTML Over The Wire**

「ワイヤー（ネットワーク）越しに HTML を送る」という意味です。

### Hotwire の3つの構成要素

| 要素 | 役割 | 一言で言うと |
|------|------|-------------|
| **Turbo Drive** | ページ遷移の高速化 | リンククリック時にページ全体を置き換え |
| **Turbo Frames** | ページの一部だけを更新 | 特定の枠内だけを入れ替え |
| **Turbo Streams** | 複数箇所を同時に更新 | DOM操作をサーバーから指示 |

このチャットアプリで重要なのは **Turbo Streams** です。

### Turbo Streams とは

サーバーから「この HTML をここに追加して」という**指示書**を送る仕組みです。

```html
<!-- これが Turbo Stream（指示書） -->
<turbo-stream action="append" target="messages">
  <template>
    <div id="message_1">
      <p>太郎</p>
      <p>こんにちは！</p>
    </div>
  </template>
</turbo-stream>
```

この指示書の意味：
- `action="append"` → 「追加して」
- `target="messages"` → 「id="messages" の要素に」
- `<template>` の中身 → 「この HTML を」

### Turbo Streams の 7 つのアクション

| アクション | 動作 |
|-----------|------|
| `append` | 末尾に追加 |
| `prepend` | 先頭に追加 |
| `replace` | 要素全体を置き換え |
| `update` | 要素の中身だけを置き換え |
| `remove` | 要素を削除 |
| `before` | 要素の前に挿入 |
| `after` | 要素の後に挿入 |

---

## 3. Action Cable とは何か

### WebSocket とは

通常の HTTP 通信は「リクエスト → レスポンス」の一方通行です。

```
HTTP:
クライアント: 「データください」
サーバー: 「はいどうぞ」
（接続終了）

クライアント: 「また欲しいです」
サーバー: 「はいどうぞ」
（接続終了）
```

WebSocket は**常時接続**で**双方向通信**ができます。

```
WebSocket:
クライアント <==> サーバー
（ずっと繋がってる）

サーバー: 「新しいデータあるよ」（いつでも送れる）
クライアント: 「受け取った！」
```

### Action Cable とは

Rails に組み込まれた WebSocket フレームワークです。

**主な概念:**

| 用語 | 説明 | 例え |
|------|------|------|
| **Channel** | 通信の「部屋」 | テレビのチャンネル |
| **Subscribe（購読）** | チャンネルに接続する | チャンネルを選局する |
| **Broadcast（配信）** | 全員に送信する | 番組を放送する |

### Action Cable の動作イメージ

```
         [Action Cable サーバー]
              /    |    \
             /     |     \
            /      |      \
    [ユーザーA] [ユーザーB] [ユーザーC]

    全員が「Room 1」チャンネルを購読中

    ↓ ユーザーAがメッセージ送信

         [Action Cable サーバー]
              ↓    ↓    ↓
         broadcast to all
              ↓    ↓    ↓
    [ユーザーA] [ユーザーB] [ユーザーC]

    全員の画面に新しいメッセージが表示される
```

---

## 4. Turbo Streams の仕組み

### turbo-rails が提供する魔法

Rails に `turbo-rails` gem を入れると、以下が使えるようになります。

#### 1. `broadcasts_to`（モデルに書く）

```ruby
class Message < ApplicationRecord
  broadcasts_to :room
end
```

これだけで、Message が作成/更新/削除されたときに自動で Turbo Stream が配信されます。

#### 2. `turbo_stream_from`（ビューに書く）

```haml
= turbo_stream_from @room
```

これだけで、その Room への配信を自動で受信します。

### broadcasts_to の内部動作

`broadcasts_to :room` は、内部的に以下と同等です：

```ruby
class Message < ApplicationRecord
  # メッセージ作成時
  after_create_commit do
    broadcast_append_to(
      room,                    # どこに送るか
      target: "messages",      # どの要素に
      partial: "messages/message",  # どのテンプレートを使うか
      locals: { message: self }     # テンプレートに渡す変数
    )
  end

  # メッセージ更新時
  after_update_commit do
    broadcast_replace_to(room)
  end

  # メッセージ削除時
  after_destroy_commit do
    broadcast_remove_to(room)
  end
end
```

### なぜ `target: "messages"` になるのか

Rails の命名規約により、モデル名から自動で決まります：

| モデル | target |
|--------|--------|
| Message | `messages` |
| Comment | `comments` |
| Post | `posts` |

ビュー側で `id="messages"` の要素を用意しておく必要があります。

---

## 5. このチャットアプリの動作フロー

### フロー図

```
┌─────────────────────────────────────────────────────────────────┐
│ ユーザーA のブラウザ                                              │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ <turbo-cable-stream-source>                              │   │
│  │   → WebSocket で Room 1 を購読中                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ <div id="messages">                                      │   │
│  │   <div id="message_1">...</div>                          │   │
│  │   <div id="message_2">...</div>                          │   │
│  │   ← ここに新しいメッセージが append される                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ <form>                                                   │   │
│  │   [名前] [メッセージ] [送信]                               │   │
│  │   → Turbo が非同期で POST                                 │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

                              │
                              │ POST /rooms/1/messages
                              ↓

┌─────────────────────────────────────────────────────────────────┐
│ Rails サーバー                                                   │
│                                                                 │
│  MessagesController#create                                      │
│    │                                                            │
│    ├─→ Message.create (DBに保存)                                │
│    │                                                            │
│    └─→ broadcasts_to :room が発動                               │
│          │                                                      │
│          ├─→ _message.html.haml をレンダリング                   │
│          │                                                      │
│          └─→ Turbo Stream を生成                                │
│                                                                 │
│  Action Cable                                                   │
│    │                                                            │
│    └─→ Room 1 を購読中の全員に Turbo Stream を配信               │
└─────────────────────────────────────────────────────────────────┘

                              │
                              │ WebSocket で配信
                              ↓

┌─────────────────────────────────────────────────────────────────┐
│ 全員のブラウザ（ユーザーA, B, C...）                              │
│                                                                 │
│  受信した Turbo Stream:                                         │
│  <turbo-stream action="append" target="messages">               │
│    <template>                                                   │
│      <div id="message_3">新しいメッセージ</div>                   │
│    </template>                                                  │
│  </turbo-stream>                                                │
│                                                                 │
│  → id="messages" に自動で追加される                              │
│  → JavaScript を書かなくても DOM が更新される                     │
└─────────────────────────────────────────────────────────────────┘
```

### ステップバイステップ

#### Step 1: ページを開く

ユーザーが `/rooms/1` にアクセスすると、以下の HTML が返されます：

```html
<!-- turbo_stream_from @room の出力 -->
<turbo-cable-stream-source
  channel="Turbo::StreamsChannel"
  signed-stream-name="Room:Z2lk...">
</turbo-cable-stream-source>

<!-- メッセージ一覧 -->
<div id="messages">
  <div id="message_1">...</div>
  <div id="message_2">...</div>
</div>

<!-- 入力フォーム -->
<form action="/rooms/1/messages" method="post">
  ...
</form>
```

`<turbo-cable-stream-source>` が読み込まれた瞬間に、**自動で WebSocket 接続が確立**されます。

#### Step 2: メッセージを送信

フォームの「送信」ボタンをクリックすると：

1. Turbo がフォーム送信を**横取り**する
2. ページ遷移せずに、**非同期で POST リクエスト**を送る
3. リクエストヘッダーに `Accept: text/vnd.turbo-stream.html` が付く

#### Step 3: サーバーで処理

`MessagesController#create` が実行されます：

```ruby
def create
  @room = Room.find(params[:room_id])
  @message = @room.messages.create(message_params)
  # ↑ ここで Message が作成され、broadcasts_to が発動

  respond_to do |format|
    format.turbo_stream  # 送信者へのレスポンス
    format.html { redirect_to room_path(@room) }
  end
end
```

`Message.create` の瞬間に `broadcasts_to :room` が発動し、**Action Cable 経由で全員に配信**されます。

#### Step 4: 全員の画面が更新

配信された Turbo Stream を受け取ったブラウザは：

1. `action="append"` を解釈
2. `target="messages"` で要素を探す
3. `<template>` の中身を追加

**JavaScript を1行も書いていないのに、DOM が自動更新されます。**

---

## 6. コード解説

### モデル

#### app/models/room.rb

```ruby
class Room < ApplicationRecord
  has_many :messages, dependent: :destroy
end
```

- `has_many :messages`: 1つの Room は複数の Message を持つ
- `dependent: :destroy`: Room を削除したら、関連する Message も削除

#### app/models/message.rb

```ruby
class Message < ApplicationRecord
  belongs_to :room
  broadcasts_to :room
end
```

- `belongs_to :room`: 1つの Message は1つの Room に属する
- `broadcasts_to :room`: **これが全ての魔法の源**
  - Message の作成/更新/削除時に自動で Turbo Stream を配信

### コントローラー

#### app/controllers/rooms_controller.rb

```ruby
class RoomsController < ApplicationController
  def index
    @rooms = Room.all  # 全ルームを取得
  end

  def show
    @room = Room.find(params[:id])  # 指定されたルームを取得
    @message = Message.new          # フォーム用の空のメッセージ
  end
end
```

#### app/controllers/messages_controller.rb

```ruby
class MessagesController < ApplicationController
  def create
    @room = Room.find(params[:room_id])
    @message = @room.messages.create(message_params)
    # ↑ この瞬間に broadcasts_to が発動して全員に配信される

    respond_to do |format|
      format.turbo_stream  # Turbo Stream 形式でレスポンス
      format.html { redirect_to room_path(@room) }  # フォールバック
    end
  end

  private

  def message_params
    params.expect(message: [:content, :sender_name])
  end
end
```

**ポイント:**
- `respond_to` で Turbo Stream と HTML の両方に対応
- `format.turbo_stream` は何も返さなくてOK（broadcasts_to が処理済み）

### ビュー

#### app/views/rooms/show.html.haml

```haml
.max-w-2xl.mx-auto.p-6.h-screen.flex.flex-col
  %h1.text-2xl.font-bold.mb-4= @room.name

  -# ★ これが WebSocket 購読を開始する
  = turbo_stream_from @room

  -# ★ id="messages" が重要（Turbo Stream の target になる）
  #messages.flex-1.overflow-y-auto.space-y-3.mb-4.p-4.bg-gray-100.rounded-lg
    = render @room.messages

  = render 'messages/form', room: @room, message: @message
```

**重要なポイント:**

1. `turbo_stream_from @room`
   - この Room への Turbo Stream 配信を購読
   - WebSocket 接続を自動で確立

2. `#messages`（`id="messages"`）
   - `broadcasts_to` は `target: "messages"` に配信する
   - この ID が一致していないと動かない

3. `render @room.messages`
   - 既存のメッセージを表示
   - 内部で `_message.html.haml` を使う

#### app/views/messages/_message.html.haml

```haml
%div{ id: dom_id(message), class: "bg-white p-3 rounded-lg shadow-sm" }
  %p.text-sm.font-semibold.text-blue-600= message.sender_name
  %p.text-gray-800= message.content
```

**重要なポイント:**

1. `dom_id(message)`
   - `message_1`, `message_2` のような一意の ID を生成
   - 更新・削除時にこの ID で要素を特定する

2. **ファイル名と場所が重要**
   - `broadcasts_to` は `messages/_message` を探す
   - 命名規約に従わないと動かない

#### app/views/messages/_form.html.haml

```haml
= form_with model: [room, message], class: "flex gap-2" do |f|
  = f.text_field :sender_name, placeholder: "名前", class: "..."
  = f.text_field :content, placeholder: "メッセージを入力", class: "..."
  = f.submit "送信", class: "..."
```

**重要なポイント:**

1. `model: [room, message]`
   - ネストしたリソース `/rooms/:room_id/messages` に POST
   - Rails が自動で正しいパスを生成

2. `form_with` はデフォルトで Turbo 対応
   - `data-turbo="true"` が自動で付く
   - 送信時にページ遷移しない

---

## 7. よくある疑問

### Q1: Action Cable のチャンネルはどこで定義してるの？

**A:** `turbo-rails` gem が自動で `Turbo::StreamsChannel` を提供しています。自分でチャンネルを定義する必要はありません。

```ruby
# turbo-rails 内部（参考）
class Turbo::StreamsChannel < ActionCable::Channel::Base
  def subscribed
    stream_from params[:signed_stream_name]
  end
end
```

### Q2: `broadcasts_to :room` の `:room` って何？

**A:** Message モデルの `belongs_to :room` で定義した関連名です。

```ruby
class Message < ApplicationRecord
  belongs_to :room      # ← この関連名
  broadcasts_to :room   # ← ここで使ってる
end
```

これにより、「この Message が属する Room を購読している全員」に配信されます。

### Q3: 複数のルームに同時に購読できる？

**A:** はい、できます。複数の `turbo_stream_from` を書けば、複数のチャンネルを購読できます。

```haml
= turbo_stream_from @room1
= turbo_stream_from @room2
= turbo_stream_from current_user  # ユーザー個人への通知など
```

### Q4: format.turbo_stream で何を返してるの？

**A:** 実は何も返す必要がありません。

```ruby
respond_to do |format|
  format.turbo_stream  # ← 空でOK
end
```

なぜなら、`@room.messages.create` の時点で `broadcasts_to` が発動し、**WebSocket 経由で全員に配信済み**だからです。

送信者本人への更新も、WebSocket 経由で届きます。

### Q5: JavaScript が無効だとどうなる？

**A:** `format.html` のフォールバックが動きます。

```ruby
respond_to do |format|
  format.turbo_stream  # JS 有効時
  format.html { redirect_to room_path(@room) }  # JS 無効時
end
```

リダイレクトでページ全体が再読み込みされ、最新の状態が表示されます。これを **Progressive Enhancement（段階的強化）** と呼びます。

### Q6: 本番環境では何が必要？

**A:** Redis が必要です。

開発環境では `async` アダプター（メモリ内）を使っていますが、本番環境では複数のサーバープロセス間で通信を共有するために Redis が必要です。

```yaml
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") %>
```

```ruby
# Gemfile
gem "redis"  # コメントアウトを解除
```

### Q7: broadcasts_to 以外の配信方法は？

**A:** 手動で配信することもできます。

```ruby
# コントローラーやモデル内で
Turbo::StreamsChannel.broadcast_append_to(
  @room,
  target: "messages",
  partial: "messages/message",
  locals: { message: @message }
)

# または
@room.broadcast_append_to(
  :messages,  # target
  partial: "messages/message",
  locals: { message: @message }
)
```

これは `broadcasts_to` では対応できない複雑なケースで使います。

---

## まとめ

### 最小構成で必要なもの

1. **モデル**に `broadcasts_to :関連名`
2. **ビュー**に `turbo_stream_from @オブジェクト`
3. **ビュー**に `id="複数形"` の要素
4. **部分テンプレート** `_単数形.html.haml` に `dom_id` 付きの要素

### Rails の規約に従うだけ

```ruby
# モデル
class Message < ApplicationRecord
  belongs_to :room
  broadcasts_to :room  # ← 追加するだけ
end
```

```haml
-# ビュー
= turbo_stream_from @room      -# 購読
#messages                       -# target
  = render @room.messages       -# 表示
```

```haml
-# 部分テンプレート
%div{ id: dom_id(message) }    -# 一意のID
  = message.content
```

**これだけでリアルタイム機能が完成します。**

従来なら JavaScript で WebSocket の接続管理、メッセージの送受信、DOM の更新を全て書く必要がありました。Hotwire + Action Cable なら、Rails の規約に従うだけで全て自動化されます。
