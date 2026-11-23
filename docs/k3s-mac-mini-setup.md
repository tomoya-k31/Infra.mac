# k3s サーバー（Mac mini 2018）: Ansible 実行前の準備

`k3s-mac-mini.yml` を実行する前に、手動で一度だけ行う手順です。
SSH 秘密鍵と sudo パスワードは 1Password に置き、このリポジトリには参照先（`op://...`）だけを書きます。

| 対象 | 保存場所 | 使い方 |
|---|---|---|
| SSH 秘密鍵 | 1Password `Dev` / `k3s-mac-mini-2018-ssh` | 1Password SSH Agent 経由（ディスクに出さない） |
| SSH 公開鍵 | `~/.ssh/k3s-mac-mini-2018.pub` | 使う鍵の指定とサーバーへの登録 |
| sudo パスワード | 1Password `Dev` / `k3s-mac-mini-2018` | `scripts/become-password.sh` |
| kubeconfig | `~/.kube/config-home`（Ansible が作成） | クラスタの管理者権限を持つ。Git に入れない |

> このリポジトリは public です。パスワード、鍵、kubeconfig、MAC アドレスは書かないでください。
> MAC アドレスが必要になったら `ansible_facts['default_ipv4']['macaddress']` で実機から取得します。

## 前提

サーバー側：

- Ubuntu Server 26.04 LTS を導入済みで、OpenSSH server が動いている
- IP アドレスを `192.168.11.200` に固定済み（netplan は Ansible の管理外）
- `tomoya-k31` ユーザーにパスワードで SSH ログインでき、sudo が使える
- ufw が無効、または未導入（ファイアウォールは Ansible の管理外）
- `/usr/bin/sudo.ws` がある（理由は [sudo.ws を使う理由](#sudows-を使う理由)）

手元の Mac 側：

- Ansible、1Password アプリ、1Password CLI（`op`）、`jq` を導入済み
- 1Password の「設定 → 開発者」で、SSH Agent と CLI 連携を有効にしている

以下はすべて手元の Mac（zsh）で実行します。

## 1. SSH 鍵を作る

```shell
op item create --category ssh --title "k3s-mac-mini-2018-ssh" --vault Dev
```

公開鍵だけを書き出します。

```shell
op read "op://Dev/k3s-mac-mini-2018-ssh/public key" > ~/.ssh/k3s-mac-mini-2018.pub
```

## 2. SSH Agent に `Dev` 保管庫を見せる

既定で対象になるのは個人用の保管庫（Personal / Private / Employee）だけです。
`~/.config/1Password/ssh/agent.toml` に `Dev` を追加します。
このファイルがあると既定の設定は置き換わるため、個人用の保管庫も書きます。

```toml
[[ssh-keys]]
vault = "個人"

[[ssh-keys]]
vault = "Dev"
```

## 3. SSH の接続設定

`~/.ssh/config` に追記します。このホストだけ 1Password の Agent を使い、鍵を 1 本に絞ります。

```text
Host 192.168.11.200
  User tomoya-k31
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  IdentityFile ~/.ssh/k3s-mac-mini-2018.pub
  IdentitiesOnly yes
```

Agent の一覧に、公開鍵と同じ `SHA256:...` があることを確認します。

```shell
SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ssh-add -l
```

```shell
ssh-keygen -lf ~/.ssh/k3s-mac-mini-2018.pub
```

## 4. 公開鍵をサーバーに登録する

秘密鍵ファイルが手元にないため `-f` が必要です。ログインパスワードを聞かれます。

```shell
ssh-copy-id -f -i ~/.ssh/k3s-mac-mini-2018.pub -o PreferredAuthentications=password tomoya-k31@192.168.11.200
```

1Password の承認後、ユーザー名と `sudo.ws` のパスが出れば完了です。

```shell
ssh -o BatchMode=yes 192.168.11.200 'id -un; ls -l /usr/bin/sudo.ws'
```

## 5. sudo パスワードを 1Password に登録する

引数、コマンド履歴、ファイルにパスワードを残さないよう、標準入力で渡します。1 つずつ実行してください。

```shell
read -rs "SUDO_PW?sudo password: "; echo
```

```shell
printf '%s' "$SUDO_PW" | jq -R '{title:"k3s-mac-mini-2018",category:"LOGIN",fields:[{id:"username",type:"STRING",purpose:"USERNAME",label:"username",value:"tomoya-k31"},{id:"password",type:"CONCEALED",purpose:"PASSWORD",label:"password",value:.}]}' | op item create --vault Dev - >/dev/null && echo OK
```

```shell
unset SUDO_PW
```

保存した値で sudo が通ることを確認します。`sudo OK` と出れば完了です。

```shell
op read "op://Dev/k3s-mac-mini-2018/password" | ssh 192.168.11.200 'sudo.ws -k -S -p "" true && echo "sudo OK"'
```

> 登録をやり直すときは、先に古いアイテムを消してください。同名のアイテムが 2 つあると `op read` が失敗することがあります。

## 6. Ansible の疎通確認

```shell
ansible k3s -i inventory -m ping
```

`pong` が返れば準備完了です。以降は [README の Usage](../README.md#usage) を参照してください。

初回の `--check` では、まだ存在しない `k3s.yaml`、k9s の deb、`kiosk` グループを参照するタスクが `ignored` になります。`failed=0` なら問題ありません。

## 補足

### sudo.ws を使う理由

Ubuntu 26.04 の既定の sudo（sudo-rs）はパスワードプロンプトの形式が異なり、ansible-core 2.20.0 では
`become` がタイムアウトする可能性があります（[ansible/ansible#85837](https://github.com/ansible/ansible/issues/85837)）。
そのため `inventory/group_vars/k3s.yml` で `ansible_become_exe: sudo.ws` を指定しています。

### scripts/become-password.sh

実行ビットが必須です。ないと、スクリプトの本文がパスワードとして扱われます。
`localhost-mac.yml` の実行時に 1Password の認証が走らないよう、`ansible.cfg` には設定していません。

### うまくいかないとき

| 症状 | 対処 |
|---|---|
| `ssh-add -l` に鍵が出ない | `agent.toml` を確認し、1Password のロック解除または再起動をする |
| Agent のソケットにつながらない | 1Password の「設定 → 開発者」で SSH Agent を有効にする |
| `Permission denied (publickey,password)` | `ssh -v` に `Server accepts key` が出なければ、公開鍵がサーバーに未登録（手順 4） |
