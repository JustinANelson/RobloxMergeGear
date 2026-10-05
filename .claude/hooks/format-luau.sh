#!/usr/bin/env bash
# PostToolUse: format the edited .luau/.lua file with StyLua. Silent on success to save tokens.
f=$(node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);process.stdout.write((j.tool_input&&j.tool_input.file_path)||"")}catch{}})')
case "$f" in
  *.luau|*.lua) ;;
  *) exit 0 ;;
esac
command -v stylua >/dev/null 2>&1 || exit 0
out=$(stylua "$f" 2>&1) || { echo "stylua: $out" >&2; exit 2; }
exit 0
