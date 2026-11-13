#!/usr/bin/env bash
# Self-contained test suite for coconut-envdiff. Requires coconut-run.
set -uo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:$PATH"
COCONUT="${COCONUT_RUN:-coconut-run}"
command -v "$COCONUT" >/dev/null 2>&1 || { echo "FAIL: coconut-run not found"; exit 1; }
./build.sh >/dev/null
ENV="./bin/coconut-envdiff"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ pass=$((pass+1)); }
bad(){ fail=$((fail+1)); echo "FAIL: $1"; }
# assert exit code and a stdout substring
check(){ # name expected_exit expected_substring actual_exit actual_out
  local name="$1" want_rc="$2" want="$3" rc="$4" out="$5"
  if [ "$rc" != "$want_rc" ]; then bad "$name (exit $rc, want $want_rc)"; return; fi
  if [ -n "$want" ] && ! printf '%s' "$out" | grep -qF -- "$want"; then
    bad "$name (output missing '$want')"; return
  fi
  ok
}
# assert exit code and exact stdout
check_eq(){ # name expected_exit expected_out actual_exit actual_out
  local name="$1" want_rc="$2" want="$3" rc="$4" out="$5"
  if [ "$rc" != "$want_rc" ]; then bad "$name (exit $rc, want $want_rc)"; return; fi
  if [ "$out" != "$want" ]; then bad "$name (output '$out' != '$want')"; return; fi
  ok
}
# assert a substring is NOT present (secrets must never leak)
check_absent(){ # name needle actual_out
  local name="$1" needle="$2" out="$3"
  if printf '%s' "$out" | grep -qF -- "$needle"; then bad "$name (leaked '$needle')"; return; fi
  ok
}

printf 'A=1\nB=2\n' > "$TMP/same1.env"
printf 'A=1\nB=2\n' > "$TMP/same2.env"
out=$($ENV "$TMP/same1.env" "$TMP/same2.env"); rc=$?
check_eq "identical files: no diff" 0 "0 added, 0 removed, 0 changed" "$rc" "$out"

printf 'A=1\n' > "$TMP/a.env"
printf 'A=1\nB=2\n' > "$TMP/b.env"
out=$($ENV "$TMP/a.env" "$TMP/b.env"); rc=$?
check "added key" 1 "+ B" "$rc" "$out"
check "added summary" 1 "1 added, 0 removed, 0 changed" "$rc" "$out"

out=$($ENV "$TMP/b.env" "$TMP/a.env"); rc=$?
check "removed key" 1 "- B" "$rc" "$out"
check "removed summary" 1 "0 added, 1 removed, 0 changed" "$rc" "$out"

printf 'A=1\n' > "$TMP/c1.env"
printf 'A=2\n' > "$TMP/c2.env"
out=$($ENV "$TMP/c1.env" "$TMP/c2.env"); rc=$?
check "changed key" 1 "~ A" "$rc" "$out"
check "changed summary" 1 "0 added, 0 removed, 1 changed" "$rc" "$out"

printf 'SECRET=abc123\nTOKEN=xyz789\n' > "$TMP/s1.env"
printf 'SECRET=def456\nTOKEN=xyz789\n' > "$TMP/s2.env"
out=$($ENV "$TMP/s1.env" "$TMP/s2.env"); rc=$?
check "secret key reported" 1 "~ SECRET" "$rc" "$out"
check_absent "old secret value hidden" "abc123" "$out"
check_absent "new secret value hidden" "def456" "$out"

printf '# comment\n\nA=1\n' > "$TMP/cm1.env"
printf 'A=1\n' > "$TMP/cm2.env"
out=$($ENV "$TMP/cm1.env" "$TMP/cm2.env"); rc=$?
check_eq "comments and blanks ignored" 0 "0 added, 0 removed, 0 changed" "$rc" "$out"

printf 'export A=1\n' > "$TMP/ex1.env"
printf 'A=1\n' > "$TMP/ex2.env"
out=$($ENV "$TMP/ex1.env" "$TMP/ex2.env"); rc=$?
check_eq "export prefix stripped" 0 "0 added, 0 removed, 0 changed" "$rc" "$out"

printf 'A="hello"\n' > "$TMP/q1.env"
printf "A=hello\n" > "$TMP/q2.env"
out=$($ENV "$TMP/q1.env" "$TMP/q2.env"); rc=$?
check_eq "matching quotes stripped" 0 "0 added, 0 removed, 0 changed" "$rc" "$out"

printf "A='hello'\n" > "$TMP/q3.env"
out=$($ENV "$TMP/q3.env" "$TMP/q2.env"); rc=$?
check_eq "single quotes stripped" 0 "0 added, 0 removed, 0 changed" "$rc" "$out"

printf 'A=1\nA=2\n' > "$TMP/dup1.env"
printf 'A=2\n' > "$TMP/dup2.env"
out=$($ENV "$TMP/dup1.env" "$TMP/dup2.env"); rc=$?
check_eq "duplicate key last wins" 0 "0 added, 0 removed, 0 changed" "$rc" "$out"

printf '' > "$TMP/empty.env"
printf 'C=3\nA=1\nB=2\n' > "$TMP/sorted.env"
out=$($ENV "$TMP/empty.env" "$TMP/sorted.env"); rc=$?
added_lines=$(printf '%s\n' "$out" | grep '^+' | tr '\n' ' ')
check_eq "added keys sorted" 1 "+ A + B + C " "$rc" "$added_lines"

printf 'KEEP=1\nCHG=old\nDEL=gone\n' > "$TMP/m1.env"
printf 'KEEP=1\nCHG=new\nADD=fresh\n' > "$TMP/m2.env"
out=$($ENV "$TMP/m1.env" "$TMP/m2.env"); rc=$?
check_eq "combined groups in order" 1 "+ ADD
- DEL
~ CHG
1 added, 1 removed, 1 changed" "$rc" "$out"

out=$($ENV "$TMP/nope.env" "$TMP/a.env" 2>&1); rc=$?
check "missing file exits 2" 2 "no such file" "$rc" "$out"

out=$($ENV "$TMP/a.env" 2>&1); rc=$?
check "one arg exits 2" 2 "usage:" "$rc" "$out"

out=$($ENV 2>&1); rc=$?
check "no args exits 2" 2 "usage:" "$rc" "$out"

out=$($ENV "$TMP/a.env" "$TMP/b.env" "$TMP/c1.env" 2>&1); rc=$?
check "three args exits 2" 2 "usage:" "$rc" "$out"

printf 'A=\n' > "$TMP/e1.env"
printf 'A=\n' > "$TMP/e2.env"
out=$($ENV "$TMP/e1.env" "$TMP/e2.env"); rc=$?
check_eq "empty values equal" 0 "0 added, 0 removed, 0 changed" "$rc" "$out"

printf 'A=x\n' > "$TMP/e3.env"
out=$($ENV "$TMP/e1.env" "$TMP/e3.env"); rc=$?
check "empty to value is change" 1 "~ A" "$rc" "$out"

echo "----------------------------------------"
echo "coconut-envdiff: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "ALL CHECKS PASSED" || exit 1