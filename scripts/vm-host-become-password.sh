#!/bin/sh
# VM ホスト（M4）の sudo パスワードを 1Password から取得する（ansible-playbook --become-password-file 用）。
# 実行ビットがないと、このファイルの本文がパスワードとして扱われるので注意。
exec op read "op://Dev/k3s-mac-mini-m4/password"
