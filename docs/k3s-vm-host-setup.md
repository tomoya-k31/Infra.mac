# k3s の VM を動かす macOS（M4 Mac mini）: Ansible 実行前の準備

`k3s-vm-host.yml` を実行する前に、手動で一度だけ行う手順です。
秘密鍵と sudo パスワードは 1Password に置き、このリポジトリには参照先だけを書きます。
1Password の SSH Agent の設定（`agent.toml`）は [k3s-mac-mini-setup.md](k3s-mac-mini-setup.md) の手順 2 と共通です。

| 対象 | 保存場所 | 使い方 |
|---|---|---|
| SSH 秘密鍵 | 1Password `Dev` / `k3s-mac-mini-m4-ssh` | 1Password SSH Agent 経由（ディスクに出さない） |
| SSH 公開鍵 | `~/.ssh/k3s-mac-mini-m4.pub` | 使う鍵の指定と M4 への登録 |
| sudo パスワード | 1Password `Dev` / `k3s-mac-mini-m4` | `inventory/host_vars/mac-mini-m4.yml` が `op read` で読む |

## 前提

- 手元の Mac は [k3s-mac-mini-setup.md の前提](k3s-mac-mini-setup.md#前提) と同じ（Ansible、1Password アプリと CLI、`jq`、SSH Agent と CLI 連携）
- M4 本体で「システム設定 → 一般 → 共有 → リモートログイン」をオンにし、自分のユーザーだけに許可している
- Command Line Tools を導入済み（`xcode-select -p` でパスが出る）。Ansible は `/usr/bin/python3` を使い、未導入だとこれが動かない。未導入なら M4 で `xcode-select --install`
- 有線 LAN でつないでいる（VM をブリッジ接続で LAN に参加させるため）
- M4 本体の IP は固定しない。mDNS の名前（以下 `<m4-hostname>.local`。M4 の「システム設定 → 一般 → 共有」の下部に表示される）で接続する
- 手元の Mac のシェルは zsh（`read` の書き方が zsh 用）

## 1. SSH 鍵を作る

```shell
op item create --category ssh --title "k3s-mac-mini-m4-ssh" --vault Dev
```

```shell
op read "op://Dev/k3s-mac-mini-m4-ssh/public key" > ~/.ssh/k3s-mac-mini-m4.pub
```

## 2. SSH の接続設定

`~/.ssh/config` に追記します。Ansible はこの `Host` 名で接続します（`inventory/hosts.yml` の `ansible_host`）。

```text
Host k3s-mac-mini-m4
  HostName <m4-hostname>.local
  User tomoya-k31
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  IdentityFile ~/.ssh/k3s-mac-mini-m4.pub
  IdentitiesOnly yes
```

Agent の一覧に、公開鍵と同じ `SHA256:...` があることを確認します。

```shell
SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ssh-add -l
```

```shell
ssh-keygen -lf ~/.ssh/k3s-mac-mini-m4.pub
```

## 3. 公開鍵を M4 に登録する

mDNS の名前には LAN の別の機器も応答できるため、初回接続でホスト鍵の確認を求められたら、M4 本体の画面で次のコマンドを実行し、表示される指紋と一致することを確かめてから `yes` と答えます。一致しなければ中止します。

```shell
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

その後、ログインパスワードを聞かれます。

```shell
ssh-copy-id -f -i ~/.ssh/k3s-mac-mini-m4.pub -o PreferredAuthentications=password,keyboard-interactive -o PubkeyAuthentication=no tomoya-k31@<m4-hostname>.local
```

```shell
ssh -o BatchMode=yes k3s-mac-mini-m4 'id -un; sw_vers -productVersion'
```

## 4. sudo パスワードを 1Password に登録する

1 つずつ実行してください。

```shell
read -rs "SUDO_PW?M4 sudo password: "; echo
```

```shell
printf '%s' "$SUDO_PW" | jq -R '{title:"k3s-mac-mini-m4",category:"LOGIN",fields:[{id:"username",type:"STRING",purpose:"USERNAME",label:"username",value:"tomoya-k31"},{id:"password",type:"CONCEALED",purpose:"PASSWORD",label:"password",value:.}]}' | op item create --vault Dev - >/dev/null && echo OK
```

```shell
unset SUDO_PW
```

```shell
op read "op://Dev/k3s-mac-mini-m4/password" | ssh k3s-mac-mini-m4 'sudo -k -S -p "" true && echo "sudo OK"'
```

## 補足

- 停電から復旧した macOS はログイン画面で止まります。VM はログインなしで動く LaunchDaemon で起動します
- FileVault を有効にすると、停電後は解除するまで VM が起動しません。Apple シリコンの macOS 26 以降は SSH で解除できますが、パスワード認証だけです。そのため SSH のパスワード認証は止めないでください。LAN からパスワードを試されうるので、ログインパスワードは推測されにくいものにします
- 「リモートユーザにフルディスクアクセスを許可」は不要です
