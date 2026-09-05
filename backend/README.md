# Xincere Backend (Cloudflare Workers + D1)

チーム全員が **Cloudflareアカウントなし** でローカルに動かせます。
`wrangler dev` はデフォルトでクラウドに一切アクセスせず、PC上にローカルのD1(SQLite)を作って動きます。

## 必要なもの

- Node.js 20 以上
- (デプロイする人だけ) Cloudflareアカウント。ローカル開発では不要。

## セットアップ手順(初回のみ)

```bash
cd backend
npm install

# JWT用のローカル秘密鍵ファイルを作成(本番の鍵とは別物。何でもいい)
echo 'JWT_SECRET="local-dev-secret-change-me"' > .dev.vars

# ローカルDBにテーブルを作成(自分のPC内にファイルができるだけ。クラウドには触らない)
npx wrangler d1 execute xincere-db --local --file=schema.sql
```

## 起動

```bash
npx wrangler dev
```

`Ready on http://localhost:8787` と出たら起動完了。この状態でAPIを叩けます。

```bash
# 動作確認例
curl http://localhost:8787/auth/register \
  -X POST -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"pass1234","name":"テスト太郎"}'
```

## iOSアプリからローカルAPIに繋ぐ

`Xincere_Hackathon/Network/APIClient.swift` の `baseURL` を確認してください。
`useLocalDev = true` にすると、Xcodeシミュレータから `http://localhost:8787` (このコマンドを起動しているPC自身)に繋がります。

- **Xcodeシミュレータ**: `localhost` のままでOK(Macの中で完結するため)
- **実機(iPhone実物)でテストする場合**: `localhost` ではなく、開発PCのLAN IP(`ifconfig`/`ipconfig getifaddr en0` で確認)に書き換えてください。例: `http://192.168.1.23:8787`

## データを見る/リセットしたい場合

```bash
# ローカルDBの中身を直接見る
npx wrangler d1 execute xincere-db --local --command "SELECT * FROM users"

# ローカルDBを作り直す(既存データは消える)
rm -rf .wrangler/state
npx wrangler d1 execute xincere-db --local --file=schema.sql
```

## 本番デプロイについて

`main` ブランチに `backend/**` の変更をpushすると `.github/workflows/deploy-backend.yml` が自動でCloudflareにデプロイします。
これは実際のクラウド環境(Cloudflareアカウント)に触れるので、担当者以外は普段意識しなくてOKです。ローカル開発は上記の手順だけで完結します。
