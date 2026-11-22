# Ansible 構成の改善プラン

2026-11 時点の調査に基づく提案です。段階 0 だけ実施済みで、段階 1 以降は着手前に承認を得ます。

## 対象と方針

| 対象 | 現在 | 将来 |
|---|---|---|
| 開発用 Mac | `localhost-mac.yml`（全台同じ内容） | 複数台。用途ごとに差分を持つ |
| k3s サーバー | Mac mini 2018、単一ノード、SQLite | 稼働を続ける |
| 追加の k3s ノード | なし | agent から始める |

公式の [Tips](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html) は「Keep it simple」、[Red Hat CoP](https://redhat-cop.github.io/automation-good-practices/) は規則を厳格に適用しすぎないよう求めています。個人の小さなリポジトリなので、必要になった段階で次へ進みます。

## 現状の評価

良い点: FQCN、`ansible-lint` の production プロファイル、チェックサム（k3s、k9s）、`no_log`、タスク単位の `become`、CI、SHA と lockfile による Actions の固定。

| 優先 | 課題 | 場所 |
|---|---|---|
| 高 | クラスタのバックアップがない（SQLite と server token） | k3s |
| 高 | 変数が play にあり、ノードの追加時に共有できない | `k3s-mac-mini.yml:8` |
| 高 | `hosts: k3s` が全ノードに server を入れる。agent を区別できない | `k3s-mac-mini.yml`、`inventory.yml` |
| 高 | kubeconfig をホストごとに同じファイルへ書く。複数台では最後のノードで上書きされる | `tasks/k3s/kubeconfig.yml` |
| 高 | `config.yaml` が 0644。join 用の token を書けない | `tasks/k3s/server.yml` |
| 中 | Mac ごとの差分を表せない | `tasks/homebrew.yml` |
| 中 | SOPS と hishtory にチェックサムがない。git-worktree-runner は `main` を追う | `tasks/tools.yml` |
| 中 | SDKMAN の取得失敗を検出できず、毎回実行される | `tasks/langs.yml` |
| 中 | `Show failed packages` は動かない（先に play が失敗する） | `tasks/homebrew.yml` |
| 低 | 新しい Mac の dry-run は、git-gtr のリンク作成で失敗する（clone が行われないため） | `tasks/tools.yml` |
| 低 | hishtory の設定は最後の 1 つしか失敗を検出しない | `tasks/tools.yml` |
| 低 | krew、pipx などが毎回 changed になる。`pip install` と `with_items` が残る | `tasks/tools.yml`、`tasks/langs.yml` |

## 目標の構成

```text
localhost-mac.yml            # 開発用 Mac。インベントリは使わない
k3s.yml                      # k3s_server、次に k3s_agent
vars/mac/{common,<profile>}.yml
inventory/
├── hosts.yml                # ホストとグループだけ
├── group_vars/{k3s,k3s_server,k3s_agent}.yml
└── host_vars/<host>.yml
roles/{k3s_common,k3s_server,k3s_agent,k3s_console}/   # 段階 4 で作る
tasks/                       # Mac 用。ロールにしない
```

- **Mac**: 1 台ずつ手元で実行するため、インベントリに並べません。`connection: local` のホストを複数並べると、`--limit` を忘れたときに同じ Mac へ全台分を適用してしまいます。代わりにプロファイル名（例: `personal`、`work`）で変数を選びます。公開リポジトリなので、Mac のホスト名は書きません。
- **k3s**: グループは `k3s` の下に `k3s_server` と `k3s_agent` を置きます。server 間で一致が必要な値は `group_vars` の 1 か所に置きます（[HA の要件](https://docs.k3s.io/datastore/ha-embedded)）。
- **ロール**: 2 台目のノードで共有するときに初めて作ります。
- **秘密の値**: 1Password のまま使います。Vault には移しません。

## 段階

段階ごとに別の PR にします。共通の確認は `ansible-verify` スキルです。

### 段階 0: AI による保守の基盤（実施済み）

`AGENTS.md`、スキル、保護設定、Dependabot、CI。

### 段階 1: インベントリと変数の分離

- `inventory/` に分け、play の `vars` を `group_vars` と `host_vars` へ移す。Vault のファイルは作らない
- `k3s-mac-mini.yml` の `-i` と、AGENTS.md、README、docs のコマンドを更新する
- 確認: `ansible-inventory --list` で移行前後の変数が同じ。dry-run が `changed=0`
- 危険: 低（サーバーの状態は変えない）。戻し方: revert

### 段階 2: Mac の複数台対応と指摘の修正

- Homebrew の一覧を `vars/mac/` へ移し、共通分とプロファイル分を結合する。プロファイル未指定は失敗にする
- 上の「中」「低」の課題を直す。`pipx` は Homebrew で入れる
- 確認: 各 Mac で dry-run の後に実行し、2 回目が `changed=0`。dry-run では動かない `command` のタスクがあるため、実機で 1 台ずつ確認する
- 危険: 低〜中

### 段階 3: k3s のバックアップ

- ノード追加より先に行う。SQLite のデータと server token を取得し、暗号化してサーバーの外に置く。token は復元に必須（[token](https://docs.k3s.io/cli/token)）
- 確認: 別の環境で復元を試す。復元できるまで段階 4 に進まない
- 危険: 中（整合性のある取得には停止か SQLite のバックアップ機能が要る。手順は実施時に公式文書で確認する）

### 段階 4: agent ノードの追加

- 既存のタスクを `k3s_common`、`k3s_server` に分け、`k3s_agent` を足す。既存サーバーの dry-run が `changed=0` であることを先に確認する
- join には server token ではなく agent token を使う。server token は管理者相当（[token](https://docs.k3s.io/cli/token)）。1Password に置き、`no_log` と 0600 にする
- kubeconfig は先頭の server でだけ書く。`console` と `kiosk` は画面のあるホストに限る
- ホスト名は一意、同じ L2（host-gw の条件）、10250/tcp を全ノード間、6443/tcp を agent から server へ（[要件](https://docs.k3s.io/installation/requirements)）
- 更新は server を先に 1 台ずつ、次に agent。マイナーバージョンは飛ばさない（[手動更新](https://docs.k3s.io/upgrades/manual)）
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

- 定期: Dependabot の PR を確認する。`actions.lock` も更新されているかを初回に確かめる
- 随時: `update-versions`（版の更新）、`ansible-verify`（検証）、`/ansible-cop-review`（構成の点検）
- 取り込み元の更新: `scripts/update-ai-content.sh` の ref を変え、差分の全文を確認する
- Galaxy と k3s、k9s の自動更新が必要になったら Renovate を検討する。[Galaxy](https://docs.renovatebot.com/modules/manager/ansible-galaxy/) と正規表現での更新に対応し、[`actions.lock`](https://docs.renovatebot.com/modules/manager/github-actions/) の再生成は実験的
- Copilot の cloud agent を使う場合は、`ansible-lint` を入れる設定（`copilot-setup-steps.yml`）を足す
