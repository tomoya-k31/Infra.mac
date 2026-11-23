#!/bin/bash
# 外部の AI 向けコンテンツを、コミットを固定して取り込む。
#   ai-forge: 公式の Lola（pip install lola-ai==0.7.1）で、一時プロジェクトに導入してから .claude/ へ反映する。
#   awesome-copilot: Ansible の指示ファイルを 1 つ取り込む。
# 更新するときは ref を書き換えて実行し、ステージされた差分（新しいファイルを含む）の全文を確認してからコミットする。
# ref は取り込み元の既定ブランチのコミットにする。fork だけにあるコミットも同じ URL で取得できてしまうため。
# 取り込んだファイルは直接編集しない。リポジトリ固有のルールは AGENTS.md に書く。
set -euo pipefail

lola_version=0.7.1
ai_forge_ref=a0ef94bd3efbe72e1a4e9c40909bd1858fd6fd34
awesome_copilot_ref=5dbf2fa94f560d66afc856cfc8d8cac9b0ce3120
modules=(ansible-content-development ansible-documentation ansible-collection-standards ansible-role)

# 取り込むファイルの一覧。差分に出ないファイル（.gitignore など）が紛れ込まないよう、違いがあれば止める。
expected='commands/ansible-collection-inclusion-review.md
commands/ansible-cop-review.md
commands/ansible-scaffold-collection.md
commands/ansible-scaffold-role.md
skills/ansible-markdown-docs/SKILL.md
skills/ansible-zen/SKILL.md
skills/ansible-zen/zen-of-ansible.txt
skills/write-content-tests/SKILL.md
skills/write-content-tests/reference.md
skills/write-content/SKILL.md
skills/write-content/reference.md
skills/write-module-tests/SKILL.md
skills/write-module-tests/reference.md
skills/write-module/SKILL.md
skills/write-module/reference.md'

die() { printf '%s\n' "$*" >&2; exit 1; }
fetch() { curl -fsSL --proto '=https' --proto-redir '=https' -o "$1" "$2"; }

# cd の引数の中で失敗しても set -e では止まらないため、先に変数へ入れる。
root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$root"
lola_bin=$(command -v lola) || die "lola not found: pip install lola-ai==$lola_version"
found_version=$("$lola_bin" --version)
[ "$found_version" = "lola $lola_version" ] || die "expected lola $lola_version, found $found_version"

paths=(.github/instructions/ansible.instructions.md third_party/ai-forge third_party/awesome-copilot)
while IFS= read -r file; do
  case $file in
    skills/*) paths+=(".claude/$(dirname "$file")") ;;
    *) paths+=(".claude/$file") ;;
  esac
done <<< "$expected"
dirty=$(git status --porcelain -- "${paths[@]}")
[ -z "$dirty" ] || die "uncommitted changes in imported files:"$'\n'"$dirty"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/src" "$tmp/project"
fetch "$tmp/ai-forge.tgz" "https://codeload.github.com/ansible-community/ai-forge/tar.gz/$ai_forge_ref"
tar -xzf "$tmp/ai-forge.tgz" -C "$tmp/src" --strip-components 1
awesome="https://raw.githubusercontent.com/github/awesome-copilot/$awesome_copilot_ref"
fetch "$tmp/upstream.instructions.md" "$awesome/instructions/ansible.instructions.md"
fetch "$tmp/awesome-copilot-LICENSE" "$awesome/LICENSE"

# Lola はモジュール内のフックを実行し、リンクの先を読み、直下の SKILL.md の name を出力先のパスに使う。
# どれもあれば導入前に止める。検査したファイルだけを使わせるため、カタログや git ではなく展開したフォルダーから導入する。
bad=$(find "$tmp/src" \( -type l -o -iname 'lola.y*ml' \))
for module in "${modules[@]}"; do
  bad+=$(find "$tmp/src/$module" -maxdepth 2 -iname SKILL.md)
done
[ -z "$bad" ] || die "not allowed in modules:"$'\n'"$bad"

# 状態は一時ディレクトリに置き、環境変数（トークンなど）は渡さない。
# Lola は CLAUDE.md にも各モジュールの文章を書き込むが、.claude/ だけを反映するので取り込まれない。
# 依存パッケージが Python のユーザー領域にあることがあるため、その場所だけは渡す。
user_base=$(python3 -m site --user-base)
lola() {
  env -i HOME="$tmp/home" LOLA_HOME="$tmp/lola" TMPDIR="$tmp" PYTHONUSERBASE="$user_base" PATH="$PATH" LC_ALL=en_US.UTF-8 \
    "$lola_bin" "$@" </dev/null
}
mkdir "$tmp/home"
git -C "$tmp/project" init -q
for module in "${modules[@]}"; do
  lola mod add "$tmp/src/$module" -n "$module" --module-content module
  lola install "$module" -a claude-code "$tmp/project"
done

# ここまでに問題があれば、リポジトリを変更せずに止める。
found=$(cd "$tmp/project/.claude" && find . ! -type d | sed 's|^\./||' | LC_ALL=C sort)
[ "$found" = "$expected" ] || die "unexpected files:"$'\n'"$(diff <(printf '%s\n' "$expected") <(printf '%s\n' "$found") || true)"
while IFS= read -r file; do
  cat "$tmp"/src/*/module/"$file" | cmp -s - "$tmp/project/.claude/$file" || die "differs from the source: $file"
done <<< "$expected"
# 対象を Ansible のファイルに絞る（元は全 YAML で、GitHub Actions も含まれる）。本文は変えない。
sed "s|^applyTo: .*|applyTo: 'localhost-mac.yml, k3s-mac-mini.yml, requirements.yml, tasks/**/*.yml, roles/**/*.yml, inventory/**/*.yml, group_vars/**/*.yml, host_vars/**/*.yml'|" \
  "$tmp/upstream.instructions.md" > "$tmp/ansible.instructions.md"
grep -q "^applyTo: 'localhost-mac" "$tmp/ansible.instructions.md" || die "applyTo not found in ansible.instructions.md"

mkdir -p .github/instructions third_party/ai-forge third_party/awesome-copilot
# 上流で消えたファイルを残さない。スキルやコマンドごと消えたときは、expected から外して手で削除する。
while IFS= read -r file; do
  case $file in skills/*) rm -rf ".claude/$(dirname "$file")" ;; esac
done <<< "$expected"
while IFS= read -r file; do
  mkdir -p ".claude/$(dirname "$file")"
  cp "$tmp/project/.claude/$file" ".claude/$file"
done <<< "$expected"
cp "$tmp/src/LICENSE" third_party/ai-forge/LICENSE
cp "$tmp/ansible.instructions.md" .github/instructions/ansible.instructions.md
cp "$tmp/awesome-copilot-LICENSE" third_party/awesome-copilot/LICENSE

# 新しいファイルも差分に出るように、取り込んだパスだけをステージする。
git add -A -- "${paths[@]}"
