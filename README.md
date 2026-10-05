# NoSleep

メニューバーから `caffeinate -dimsu` と `sudo pmset -a disablesleep 1` をワンクリックで切り替えるアプリ。

## ビルド

```sh
./build.sh        # NoSleep.app を生成
open NoSleep.app  # 起動（メニューバーにコーヒーカップのアイコンが出る）
```

## 使い方

- メニューバーのアイコン → 「スリープ防止を有効化」
  - `caffeinate -dimsu` を起動
  - `sudo -n pmset -a disablesleep 1` を実行
- 「スリープ防止を無効化」またはアプリ終了で `caffeinate` を止め、`pmset -a disablesleep 0` に戻す
- 「VRAM 割り当てを変更…」→ 物理メモリに対する割合（5〜95%）をスライダーで選び、`sudo sysctl iogpu.wired_limit_mb=<MB>` に換算して実行
  - Apple Silicon の GPU メモリ上限を変更（LLM などで GPU メモリを増やしたいとき用）
  - 「デフォルトに戻す」で `0`（自動）に復帰。再起動で自動リセット

## sudoers 設定（pmset のパスワードレス化）

メニューの「管理者権限をセットアップ…」を押すか、手動で:

```sh
sudo ./install-sudoers.sh
```

`/etc/sudoers.d/nosleep-pmset` に以下の NOPASSWD 権限だけを追加する。

- `/usr/bin/pmset -a disablesleep 0` / `1`
- `/usr/sbin/sysctl iogpu.wired_limit_mb=*`
設定がなくても `caffeinate` だけは動く（`pmset` 部分だけ失敗して警告が出る）。

## 削除

```sh
sudo rm /etc/sudoers.d/nosleep-pmset
sudo pmset -a disablesleep 0   # もし 1 のままなら
```
