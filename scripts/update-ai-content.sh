#!/bin/bash
# 外部の AI 向けコンテンツを、コミットを固定して取り込む。
# 更新するときは ref を書き換えて実行し、ステージされた差分（新しいファイルを含む）の全文を確認してからコミットする。
# ref は取り込み元の既定ブランチのコミットにする。fork だけにあるコミットも同じ URL で取得できてしまうため。
# 取り込んだファイルは直接編集しない。リポジトリ固有のルールは AGENTS.md に書く。
set -euo pipefail

ai_forge_ref=a0ef94bd3efbe72e1a4e9c40909bd1858fd6fd34
awesome_copilot_ref=5dbf2fa94f560d66afc856cfc8d8cac9b0ce3120

# cd の引数の中で失敗しても set -e では止まらないため、先に変数へ入れる。
root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$root"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/ai-forge"

fetch() { curl -fsSL --proto '=https' --proto-redir '=https' -o "$1" "$2"; }
fetch "$tmp/ai-forge.tgz" "https://codeload.github.com/ansible-community/ai-forge/tar.gz/$ai_forge_ref"
tar -xzf "$tmp/ai-forge.tgz" -C "$tmp/ai-forge" --strip-components 1
awesome="https://raw.githubusercontent.com/github/awesome-copilot/$awesome_copilot_ref"
fetch "$tmp/upstream.instructions.md" "$awesome/instructions/ansible.instructions.md"
fetch "$tmp/awesome-copilot-LICENSE" "$awesome/LICENSE"

src="$tmp/ai-forge"
skills=("$src/ansible-content-development/module/skills/write-content"
  "$src/ansible-documentation/module/skills/ansible-markdown-docs")
commands=("$src/ansible-collection-standards/module/commands/ansible-cop-review.md"
  "$src/ansible-role/module/commands/ansible-scaffold-role.md")

# 対象を Ansible のファイルに絞る（元は全 YAML で、GitHub Actions も含まれる）。本文は変えない。
sed "s|^applyTo: .*|applyTo: '*.yml, tasks/**/*.yml, roles/**/*.yml, inventory/**/*.yml, group_vars/**/*.yml, host_vars/**/*.yml'|" \
  "$tmp/upstream.instructions.md" > "$tmp/ansible.instructions.md"

# ここまでに問題があれば、リポジトリを変更せずに止める。
for skill in "${skills[@]}"; do test -f "$skill/SKILL.md"; done
for file in "${commands[@]}" "$src/LICENSE"; do test -f "$file"; done
grep -q "^applyTo: '\*\.yml, tasks/" "$tmp/ansible.instructions.md"
links=$(find "${skills[@]}" "${commands[@]}" "$src/LICENSE" -type l)
if [ -n "$links" ]; then
  echo "symlink found: $links" >&2
  exit 1
fi

mkdir -p .claude/skills .claude/commands .github/instructions third_party/ai-forge third_party/awesome-copilot
for skill in "${skills[@]}"; do
  rm -rf ".claude/skills/${skill##*/}"
  cp -R "$skill" .claude/skills/
done
cp "${commands[@]}" .claude/commands/
cp "$src/LICENSE" third_party/ai-forge/LICENSE
cp "$tmp/ansible.instructions.md" .github/instructions/ansible.instructions.md
cp "$tmp/awesome-copilot-LICENSE" third_party/awesome-copilot/LICENSE

# 新しいファイルも差分に出るように、取り込んだパスだけをステージする。
git add -A -- .claude/skills/write-content .claude/skills/ansible-markdown-docs \
  .claude/commands/ansible-cop-review.md .claude/commands/ansible-scaffold-role.md \
  .github/instructions/ansible.instructions.md third_party/ai-forge third_party/awesome-copilot
