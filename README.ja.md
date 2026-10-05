# NoSleep

[English README](README.md)

`caffeinate -dimsu` + `sudo pmset -a disablesleep 1` をメニューバーからワンクリックで切り替え、さらに Apple Silicon の GPU メモリ上限（`iogpu.wired_limit_mb`）をパーセントスライダーで変更できる macOS アプリ。

![macOS](https://img.shields.io/badge/macOS-14%2B-black) ![License](https://img.shields.io/badge/license-MIT-green)

## インストール

[Releases](../../releases) から `NoSleep.zip` をダウンロードして解凍し、`NoSleep.app` を好きな場所に置く。

アプリは ad-hoc 署名のため、ダウンロード後に quarantine フラグを外してください:

```sh
xattr -d com.apple.quarantine NoSleep.app
open NoSleep.app
```

ソースからビルドする場合:

```sh
./build.sh        # NoSleep.app を生成
open NoSleep.app  # メニューバーにコーヒーカップのアイコンが出る
```

## 使い方

- **スリープ防止を有効化** — `caffeinate -dimsu` を起動し、`sudo -n pmset -a disablesleep 1` を実行
- **無効化 / アプリ終了** — `caffeinate` を停止し、`pmset -a disablesleep 0` に復元
- **VRAM 割り当てを変更…** — 物理メモリの 5〜95% をスライダーで選び、`sudo sysctl iogpu.wired_limit_mb=<MB>` を実行
  - LLM などで GPU メモリを増やしたいとき用
  - 「デフォルトに戻す」で `0`（自動）に復帰。再起動で自動リセット

## sudoers 設定（pmset / sysctl のパスワードレス化）

メニューの「**管理者権限をセットアップ…**」を押すか、手動で:

```sh
sudo ./install-sudoers.sh
```

`/etc/sudoers.d/nosleep-pmset` に以下の NOPASSWD 権限だけを追加します。

- `/usr/bin/pmset -a disablesleep 0` / `1`
- `/usr/sbin/sysctl iogpu.wired_limit_mb=*`

設定がなくても `caffeinate` は動きます（`pmset`/`sysctl` 部分だけ失敗して警告が出ます）。

## 多言語対応

英語と日本語に対応。macOS のシステム言語に自動で追従します。

## アンインストール

```sh
sudo rm /etc/sudoers.d/nosleep-pmset
sudo pmset -a disablesleep 0   # もし 1 のままなら
rm -rf NoSleep.app
```
