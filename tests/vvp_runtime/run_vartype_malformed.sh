#!/bin/sh
# A .vartype record (enum / packed struct type of a signal, for vpiTypespec)
# that is malformed, names a missing signal, or disagrees with the signal's
# width must make the image fail to load, never attach a wrong type.
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
vvp=${VVP:-$repo_dir/local-install/bin/vvp}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/vartype-malformed.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

cat >"$work_dir/t.sv" <<'SV'
module top;
  typedef struct packed { logic [3:0] hi; bit lo; } s_t;
  s_t s;
  initial begin s = 0; $display("loaded"); end
endmodule
SV
"$iverilog" -g2017 -o "$work_dir/good.vvp" "$work_dir/t.sv"
line=$(grep '^ \.vartype ' "$work_dir/good.vvp") || {
  echo "FAIL no .vartype record emitted" >&2; exit 1; }
"$vvp" -n "$work_dir/good.vvp" | grep -q '^loaded$' || {
  echo "FAIL well-formed .vartype did not load" >&2; exit 1; }

check() { # name sed-expression
  sed "$2" "$work_dir/good.vvp" >"$work_dir/$1.vvp"
  if "$vvp" -n "$work_dir/$1.vvp" >"$work_dir/$1.log" 2>&1; then
    cat "$work_dir/$1.log"; echo "FAIL $1 loaded" >&2; exit 1
  fi
  grep -q 'invalid .vartype metadata' "$work_dir/$1.log" || {
    cat "$work_dir/$1.log"; echo "FAIL $1: no .vartype diagnostic" >&2; exit 1; }
  echo "PASS $1"
}
check width-mismatch 's/hi=V3:0/hi=V4:0/'
check bad-syntax 's/S{hi=/S{hi/'
check missing-signal "s/ \.vartype v[^,]*,/ .vartype vnosuch_0,/"
check missing-enum 's/hi=V3:0/hi=E4:enum0xdead/'
