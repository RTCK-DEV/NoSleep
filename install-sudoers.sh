#!/bin/sh
# NoSleep がパスワードなしで pmset / sysctl(iogpu.wired_limit_mb) を実行できるようにする
# 使い方: sudo ./install-sudoers.sh
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "sudo で実行してください: sudo $0" >&2
    exit 1
fi

USER_NAME="${SUDO_USER:-$(id -un)}"
f=/etc/sudoers.d/nosleep-pmset
printf '%s\n' "$USER_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1, /usr/sbin/sysctl iogpu.wired_limit_mb=*" > "$f.tmp"
chmod 440 "$f.tmp"
if ! visudo -cf "$f.tmp" > /dev/null; then
    rm -f "$f.tmp"
    echo "sudoers ファイルの検証に失敗しました" >&2
    exit 1
fi
mv "$f.tmp" "$f"
echo "インストール完了: $f"
echo "アンインストール: sudo rm $f"
