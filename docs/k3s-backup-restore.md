# k3s のバックアップと復元

k3s のデータストアは SQLite（`/var/lib/rancher/k3s/server/db/state.db`）です。
復元には、データストアと server token（`/var/lib/rancher/k3s/server/token`）の両方が必要です。
token はデータストア内の秘密の値（bootstrap データ）の暗号化に使われ、違う token では復元したデータを使えません（[公式](https://docs.k3s.io/datastore/backup-restore)）。

> token はクラスタの管理者権限と同等です。バックアップファイルを人に渡したり、リポジトリに入れたりしないでください。

## バックアップ

k3s の更新やノードの追加の前に取ります。

```shell
ansible-playbook -i inventory k3s-mac-mini.yml --become-password-file scripts/become-password.sh --tags backup
```

- server で SQLite のオンラインバックアップを取り（WAL のため、ファイルの複製では一貫しない）、`PRAGMA integrity_check` で確かめます
- データストア、token、ノードのパスワード（`/etc/rancher/node/password`。同じホスト名で作り直した server が参加するのに要る）を tar にまとめ、手元の Mac で age により暗号化して `~/.local/share/k3s-backup/<host>-<版>-<UTC 時刻>.tar.gz.b64.age` に保存します（0600）
- ファイル名に k3s の版が入ります。復元にはその版の k3s を使います
- 暗号化には SOPS と共用の鍵ファイル `~/.config/sops/age/keys.txt` を使います（`age -e -i`）。鍵を失うと復号できません
- 鍵とバックアップは同じ Mac にあります。ホームごとの複製（Time Machine など）には両方が入るので、その複製に対しては暗号化が効きません
- 中身は tar.gz を base64 にしたものです。復号の結果は `base64 -d` で tar.gz に戻します
- 平文は server の root だけが入れる一時ディレクトリと Ansible のメモリにだけ置き、終わったら消します
- 失敗したときは、作りかけのファイルを消します。成功したものだけが正規の名前で残ります
- 古いバックアップは自動では消しません
- `ANSIBLE_DEBUG` を付けて実行しないでください。`no_log` が効かず、内容がログに出ます
- 実行を中断すると、server の `/tmp/k3s-backup.*` に平文が残ることがあります。`sudo rm -rf /tmp/k3s-backup.*` で消します。復元の途中で止めたときは、展開した `/tmp/tmp.*` も消します

## 復元

バックアップのファイル名にある版の k3s を入れ、一度起動した server で行います（playbook で入れれば起動しています）。手元の Mac で復号して server へ直接流し込み、ログインユーザーだけが読める一時ディレクトリに展開します（手元のディスクには平文を書かない）。データを流している ssh ではパスワードを入力できないため、ここでは sudo を使いません。

```shell
B=~/.local/share/k3s-backup/<file>.tar.gz.b64.age
age -d -i ~/.config/sops/age/keys.txt "$B" | base64 -d | ssh <server> 'umask 077 && d=$(mktemp -d) && tar -xzf - -C "$d" && echo "$d"'
```

server に ssh で入り、表示されたディレクトリを `d` に入れてから実行します。今のデータストア、token、ノードのパスワード、証明書（`tls`、`cred`）は `pre-restore` に退避します。証明書はバックアップのデータストアから書き戻されます（ディスクの証明書の方が新しいと、k3s は起動しません）。途中で失敗したら、その時点で止まります（ログインシェルは閉じません）。展開したディレクトリは、成功しても失敗しても消します。

```shell
d=<表示されたディレクトリ>
sudo bash -eu -c '
d=$1
# 貼り付けを誤ったまま root で消さないよう、mktemp が作ったディレクトリであることを先に確かめる。
case $d in /tmp/tmp.*) ;; *) echo "unexpected d: $d" >&2; exit 1;; esac
test -d "$d" && test ! -L "$d" && test "$(stat -c %U "$d")" = "$SUDO_USER"
trap '\''rm -rf "$d"'\'' EXIT
s=/var/lib/rancher/k3s/server
n=/etc/rancher/node
for f in state.db token password; do test -f "$d/$f"; done
for f in "$s/db" "$s/token" "$s/tls" "$s/cred" "$n/password"; do test -e "$f"; done
test ! -e "$s/pre-restore"
systemctl stop k3s
mkdir -m 700 "$s/pre-restore"
cp -a "$s/db" "$s/token" "$n/password" "$s/pre-restore/"
mv "$s/tls" "$s/cred" "$s/pre-restore/"
install -m 600 "$d/state.db" "$s/db/state.db"
install -m 600 "$d/token" "$s/token"
install -m 600 "$d/password" "$n/password"
rm -f "$s/db/state.db-wal" "$s/db/state.db-shm"
systemctl start k3s
' _ "$d"
# 別のホスト名に復元したときは、ノードが登録されるまで待つ。
timeout 180 bash -c 'until sudo k3s kubectl wait --for=condition=Ready "node/$(hostname | tr A-Z a-z)" --timeout=10s 2>/dev/null; do sleep 5; done'
```

- 前回の `pre-restore` が残っていると中止します。中身を確かめてから消してください
- 確認が済んだら、`pre-restore` は消します

うまくいかなかったときは、退避したものに戻します。

```shell
sudo bash -eu -c '
s=/var/lib/rancher/k3s/server
n=/etc/rancher/node
p=$s/pre-restore
# 復元が途中で止まって退避がそろっていないときは、今のファイルを消さない。
for f in db/state.db tls cred token password; do test -e "$p/$f"; done
systemctl stop k3s
rm -rf "$s/db" "$s/tls" "$s/cred"
mv "$p/db" "$p/tls" "$p/cred" "$s/"
mv "$p/token" "$s/token"
mv "$p/password" "$n/password"
rmdir "$p"
systemctl start k3s
'
```

## 復元試験の記録

| 日付 | バックアップ | 試験環境 | 結果 |
|---|---|---|---|
| 2026-11-23 | v1.37.2+k3s1、暗号化後 3.2MB | M4 上の一時的な Lima VM（NAT のみ、Ubuntu 26.04）。同じ版の k3s を固定したインストーラーで導入 | k3s が起動し、ノード、Namespace 5 個、Secret 9 個、kiosk の ServiceAccount を読めた。試験後に VM を削除 |
| 2026-11-23 | 同上（版つきのファイル名） | 同上。ただし k3s を一度起動してから、上の手順を文字どおりに実行 | 起動していたクラスタの証明書が残っていると起動しないことがわかり、`tls` と `cred` を退避する手順にした。直した手順で起動し、Secret 9 個を読めた。試験後に VM を削除 |
| 2026-11-23 | ノードのパスワードを含む形 | 同上。上の復元と巻き戻しの手順を文字どおりに実行 | 復元で Secret 9 個を読め、巻き戻しで元のクラスタに戻った。ノードの登録を待つ手順を足した後、復元が最後まで成功した。試験後に VM を削除 |

試験用の環境は、本番と同じ CA と token を持つクラスタの複製になります。LAN に参加させず（NAT のみ）、試験が終わったらすぐ消します。
