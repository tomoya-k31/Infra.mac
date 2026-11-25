# Ansible 構成の改善プラン

2026-11 時点の調査に基づく提案です。段階 0 から段階 4 までを実施済みです。残りは着手前に承認を得ます。

## 対象と方針

| 対象 | 現在 | 将来 |
|---|---|---|
| 開発用 Mac | `localhost-mac.yml`（共通 + プロファイル） | 複数台。用途ごとに差分を持つ |
| k3s サーバー | Mac mini 2018、単一ノード、SQLite | 稼働を続ける |
| 追加の k3s ノード | M4 Mac mini 上の Linux VM（agent） | 必要になったら agent を足す |

公式の [Tips](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html) は「Keep it simple」、[Red Hat CoP](https://redhat-cop.github.io/automation-good-practices/) は規則を厳格に適用しすぎないよう求めています。個人の小さなリポジトリなので、必要になった段階で次へ進みます。

## 現状の評価

良い点: FQCN、`ansible-lint` の production プロファイル、チェックサム（k3s、k9s）、`no_log`、タスク単位の `become`、CI、SHA と lockfile による Actions の固定。

指摘した課題（kubeconfig の書き込み元、Mac ごとの差分、API 停止時の再起動）はすべて対応済みです。

## 目標の構成

```text
localhost-mac.yml            # 開発用 Mac。インベントリは使わない
k3s-mac-mini.yml             # k3s_server、次に k3s_agent（目標の k3s.yml への改名は未実施）
k3s-vm-host.yml              # VM ホスト（M4 の macOS）。k3s のノードではない
vars/mac/{common,<profile>}.yml
inventory/
├── hosts.yml                # ホストとグループだけ
├── group_vars/{k3s,k3s_server,k3s_agent,vm_hosts}.yml
└── host_vars/<host>.yml
tasks/k3s/                   # server、agent、opt-in の部分。ロールには分けていない
tasks/                       # Mac 用。ロールにしない（vm_host/ は VM ホスト用）
```

- **Mac**: 1 台ずつ手元で実行するため、インベントリに並べません。`connection: local` のホストを複数並べると、`--limit` を忘れたときに同じ Mac へ全台分を適用してしまいます。代わりにプロファイル名（例: `personal`、`work`）で変数を選びます。公開リポジトリなので、Mac のホスト名は書きません。
- **k3s**: グループは `k3s` の下に `k3s_server` と `k3s_agent` を置きます。server 間で一致が必要な値は `group_vars` の 1 か所に置きます（[HA の要件](https://docs.k3s.io/datastore/ha-embedded)）。
- **ロール**: 2 台目のノードで共有するときに初めて作ります。
- **秘密の値**: 1Password のまま使います。Vault には移しません。

## 段階

段階ごとに別の PR にします。共通の確認は `ansible-verify` スキルです。

### 段階 0: AI による保守の基盤（実施済み）

`AGENTS.md`、スキル、保護設定、Dependabot、CI。

### 段階 1: インベントリと変数の分離（実施済み）

- `inventory/` に分け、play の `vars` を `group_vars` と `host_vars` へ移す。Vault のファイルは作らない
- `k3s-mac-mini.yml` の `-i` と、AGENTS.md、README、docs のコマンドを更新する
- 確認: 移行前の play の `vars` と、移行後の `ansible-inventory --host mac-mini-2018` が同じ。dry-run が `changed=0`（`--tags all,upgrade,console,kiosk` で確認。保留中の apt 更新があると upgrade のタスクだけは changed になる。最終のコミットでの `PLAY RECAP` の件数だけを PR に記載し、`--diff` の出力は載せない）
- 危険: 低（サーバーの状態は変えない）。戻し方: revert

### 段階 2: Mac の複数台対応（実施済み）

- Homebrew の一覧を `vars/mac/` へ移し、共通分とプロファイル分を結合する。プロファイル未指定は失敗にする
- 確認: 各 Mac で dry-run の後に実行し、2 回目が `changed=0`。dry-run では動かない `command` のタスクがあるため、実機で 1 台ずつ確認する
- 危険: 低〜中
- 2026-11-25、`vars/mac/common.yml` と `vars/mac/personal.yml` に分けた。`-e mac_profile=<profile>` が無いと失敗する。手元の Mac で 2 回目の実行が `changed=0`

### 段階 3: k3s のバックアップ（実施済み）

- ノード追加より先に行う。SQLite のデータと server token を取得し、暗号化してサーバーの外に置く。token は復元に必須（[token](https://docs.k3s.io/cli/token)）
- 確認: 別の環境で復元を試す。復元できるまで段階 4 に進まない（2026-11-23、M4 上の一時的な VM で復元を確認。`docs/k3s-backup-restore.md`）
- 危険: 中（整合性のある取得には停止か SQLite のバックアップ機能が要る。手順は実施時に公式文書で確認する）

### 段階 4: agent ノードの追加（実施済み）

- 2026-11-23、M4 上の VM（`lima-k3s-agent`、`192.168.11.201`）が agent として参加した。両ノードが Ready、ノード間の Pod の通信とクラスタの DNS を確認し、2 回目の実行は両ノードとも `changed=0`
- 当初はロール（`k3s_common`、`k3s_server`、`k3s_agent`）に分ける案だったが、共有するタスクが少ないため、`tasks/k3s/agent.yml` と別の play にした。server を増やすときに改めて検討する
- join には server token ではなく agent token を使う。server token は管理者相当（[token](https://docs.k3s.io/cli/token)）。1Password に置き、`no_log` と 0600 にする
- agent は server とは別の play とタスクにし、`console` と `kiosk` は server の play にだけ置く。kubeconfig は inventory の先頭の server からだけ書く（HA にするときは、固定の server と VIP のどちらを指すかを決め直す）
- M4 の macOS（VM の土台）は k3s のノードではないため、別の playbook とインベントリグループにし、タスクは `tasks/vm_host/` に置く
- M4 の VM は arm64 で、ブリッジ接続（socket_vmnet の bridged）にする。NAT では host-gw の経路が届かない。k9s の取得は amd64 の deb に固定しているので、kiosk は 2018 に限る
- ホスト名は一意、同じ L2（host-gw の条件）、10250/tcp を全ノード間、6443/tcp を agent から server へ（[要件](https://docs.k3s.io/installation/requirements)）
- 更新は server を先に 1 台ずつ、次に agent。k3s の版は共通の 1 つの値なので、playbook では server の play を agent の play より前に置き、server で失敗したら agent に進まないようにする（`any_errors_fatal`）。マイナーバージョンは飛ばさない（[手動更新](https://docs.k3s.io/upgrades/manual)）
- 危険: 中。戻し方: ノードを drain して削除する

### 段階 5: 高可用性（必要になった場合だけ）

- server は奇数、3 台以上。SQLite から組み込み etcd へは `--cluster-init` で再起動して移す（[HA](https://docs.k3s.io/datastore/ha-embedded)）
- 公式文書に戻し方の記載がないため、一方通行とみなす。段階 3 の復元を確認してから、停止時間を決めて行う

## 採用しないもの

| 案 | 理由 |
|---|---|
| k3s-ansible への置き換え | 稼働中の SQLite 構成への適用が README に書かれていない。インベントリの形だけ参考にする |
| Molecule、ステージング環境、AAP | 1 人で運用する規模に対して重い。lint、dry-run、実機確認で代える |
| Mac 用タスクのロール化 | 再利用する相手がいない |
| ai-forge の残りのモジュール | コレクションのリリース、AWS、ネットワーク機器の開発用 |
| `.lola-req` での同期 | Lola 0.7.1 ではカタログ名でのコミット固定に失敗し、固定しないと `main` を追う。URL と `#subdirectory` での固定も、同じリポジトリの複数モジュールでは失敗した |

## AI による保守

- 定期: Dependabot（GitHub Actions）と Renovate（固定したツールの版）の PR を確認する。Dependabot の PR は `actions.lock` を更新しないので、`verify-lockfile` が失敗したらそのブランチで `gh actions-lock --no-narrow` を実行する。Renovate の PR は下書きで作られる。版と組のハッシュを `update-versions` で直してから、下書きを解除してマージする
- 随時: `update-versions`（版の更新）、`ansible-verify`（検証）、`/ansible-cop-review`（構成の点検）
- 取り込み元の更新: `scripts/update-ai-content.sh` の ref を変え、差分の全文を確認する
- Renovate（`renovate.json`）を導入した。正規表現で k3s（stable チャネル）、k9s、socket_vmnet、SOPS、hishtory、gh-actions-lock の版を追う。[`actions.lock`](https://docs.renovatebot.com/modules/manager/github-actions/) の再生成は実験的なので GitHub Actions は Dependabot のまま、Galaxy のコレクションは Homebrew の ansible に合わせるので対象外
- Copilot の cloud agent を使う場合は、`ansible-lint` を入れる設定（`copilot-setup-steps.yml`）を足す
