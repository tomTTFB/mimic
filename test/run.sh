#!/usr/bin/env bash
# mimic test runner
#
# Runs test/smoke.lua inside CraftOS-PC headless and prints the results.
# Requires CraftOS-PC: https://www.craftos-pc.cc/
#
#   ./test/run.sh
#
set -uo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# locate CraftOS-PC
CRAFTOS=""
for c in \
    "/c/Program Files/CraftOS-PC/CraftOS-PC_console.exe" \
    "/c/Program Files (x86)/CraftOS-PC/CraftOS-PC_console.exe" \
    "$(command -v craftos 2>/dev/null)" ; do
    [ -n "$c" ] && [ -x "$c" ] && CRAFTOS="$c" && break
done

if [ -z "$CRAFTOS" ]; then
    echo "error: CraftOS-PC not found. Install from https://www.craftos-pc.cc/" >&2
    exit 1
fi

DATA="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/mimic-test-$$")"
trap 'rm -rf "$DATA"' EXIT
mkdir -p "$DATA/computer/0"

# stage the library at the root of computer 0's filesystem, which is where
# initenv expects to find it (require is re-rooted at "/")
cp -r "$LIB_DIR"/graphics "$LIB_DIR"/scada-common "$LIB_DIR"/mimic "$LIB_DIR"/examples "$DATA/computer/0/"
cp "$LIB_DIR"/initenv.lua "$DATA/computer/0/"

# startup.lua runs in shell context, so `require` is bootstrapped for us;
# --exec runs before the shell and would not have it
cp "$LIB_DIR"/test/smoke.lua "$DATA/computer/0/startup.lua"

# --headless streams the terminal to stdout; the test writes to /results.txt
# instead, so we do not have to screen-scrape
timeout 120 "$CRAFTOS" --headless -d "$DATA" >/dev/null 2>&1

if [ ! -f "$DATA/computer/0/results.txt" ]; then
    echo "error: no results written — the computer crashed before finishing" >&2
    exit 1
fi

cat "$DATA/computer/0/results.txt"
grep -q "0 failed" "$DATA/computer/0/results.txt"
