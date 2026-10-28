#!/usr/bin/env bash
set -euo pipefail

root=$PWD
iverilog="$root/local-install-p1/bin/iverilog"
vvp="$root/local-install-p1/bin/vvp"
timeout_runner="$root/scripts/run_with_timeout.py"
out="$root/evidence/m9-group3/array-equality-order-probe"
tmp=$(mktemp -d /tmp/a3_728_pos.XXXXXX)
mkdir -p "$out"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/positive.sv" <<'SV'
module t;
  int A[0:1][0:2];
  int B[1:0][2:0];
  int C[0:1][2:0];
  int E[5:5][7:7];
  int F[0:0][0:0];
  initial begin
    for (int i=0; i<2; i++) for (int j=0; j<3; j++) A[i][j] = 10*i+j;
    for (int i=0; i<2; i++) for (int j=0; j<3; j++) B[1-i][2-j] = A[i][j];
    for (int i=0; i<2; i++) for (int j=0; j<3; j++) C[i][2-j] = A[i][j];
    $display("AB eq=%b ne=%b ceq=%b cne=%b", A==B, A!=B, A===B, A!==B);
    $display("AC eq=%b ceq=%b", A==C, A===C);
    B[1][2] = 99;
    $display("AB neq: eq=%b ne=%b", A==B, A!=B);
    for (int i=0; i<2; i++) for (int j=0; j<3; j++) begin
      A[i][j] = 0;
      B[i][j] = 0;
    end
    A[0][0]=1; A[1][2]=2; B[0][0]=1; B[1][2]=2;
    $display("numeric-trap eq=%b (expect 0 under positional)", A==B);
    E[5][7]=3; F[0][0]=3;
    $display("size1 eq=%b (expect 1)", E==F);
  end
endmodule
SV
cat > "$tmp/negative.sv" <<'SV'
module n;
  int P[0:1][0:2];
  int Q[0:2][0:1];
  initial $display("%b", P==Q);
endmodule
SV

{
  echo "compiler=$iverilog"
  echo "runtime=$vvp"
  git rev-parse HEAD 2>/dev/null || true
  echo "BUILD"
  if [[ -d /opt/homebrew/opt/bison/bin ]]; then
    export PATH="/opt/homebrew/opt/bison/bin:$PATH"
  fi
  if [[ -f /opt/homebrew/opt/libffi/include/ffi.h ]]; then
    export CPPFLAGS="${CPPFLAGS:-} -I/opt/homebrew/opt/libffi/include"
  fi
  if [[ -f /opt/homebrew/opt/z3/include/z3.h ]]; then
    export CPPFLAGS="${CPPFLAGS:-} -I/opt/homebrew/opt/z3/include"
    export LDFLAGS="${LDFLAGS:-} -L/opt/homebrew/opt/z3/lib"
  fi
  autoconf
  ./configure --enable-libveriuser --prefix="$root/local-install-p1"
  make -j3
  make install
  run_limited() { python3 "$timeout_runner" 120 -- "$@"; }
  for edition in 2017 2023; do
    echo "POSITIVE -g$edition"
    run_limited "$iverilog" -g"$edition" -s t -o "$tmp/positive-$edition.vvp" "$tmp/positive.sv"
    run_limited "$vvp" "$tmp/positive-$edition.vvp"
  done
  expect_reject() {
    edition=$1
    op=$2
    source="$tmp/negative-$op.sv"
    output="$tmp/negative-$edition-$op.log"
    sed "s/P==Q/P$op Q/" "$tmp/negative.sv" > "$source"
    echo "NEGATIVE -g$edition operator=$op"
    if run_limited "$iverilog" -g"$edition" -s n -o "$tmp/negative.vvp" "$source" >"$output" 2>&1; then
      cat "$output"
      echo "ERROR: incompatible shapes unexpectedly compiled"
      return 1
    else
      rc=$?
      echo "compile_rc=$rc"
      cat "$output"
    fi
  }
  expect_reject 2023 ==
  expect_reject 2023 !=
  expect_reject 2017 ===
} 2>&1 | tee "$out/output.txt"
