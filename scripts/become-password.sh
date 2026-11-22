#!/bin/sh
# sudo パスワードを 1Password から取得する（ansible-playbook --become-password-file 用）。
# 実行ビットがないと、このファイルの本文がパスワードとして扱われるので注意。
exec op read "op://Dev/k3s-mac-mini-2018/password"
