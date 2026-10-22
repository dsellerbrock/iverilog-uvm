package p;
  int x;
endpackage
module m;
  import p::*;
  if (1) begin : b
    initial x = 1;
    int x;
    initial x = 1;
  end
  int x;
endmodule
EOF
cat > evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/input/N_genhier_uninstantiated.sv <<'EOF
module top;
  if (0) begin : g
    int v;
  end
  initial top.g.v = 1;
endmodule
EOF
cat > evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/input/N_gen_collide_if1_var_before.sv <<'EOF
module m;
  int g;
  if (1) begin : g
    int v;
  end
endmodule
EOF
cat > evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/input/N_gen_collide_if1_var_after.sv <<'EOF'
module m;
  if (1) begin : g
    int v;
  end
  int g;
endmodule
EOF
cat > evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/input/N_gen_collide_for.sv <<'EOF'
module m;
  for (genvar i = 0; i < 0; i = i + 1) begin : g
    int v;
  end
  int g;
endmodule
EOF
cat > evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/input/P_unit_declared_before.sv <<'EOF
bit b = 1;
task t;
  int x;
  int y;
  x = b;
  y = $unit::b;
  $display("%0d %0d", x, y);
endtask
module m;
  initial t();
endmodule
EOF
cat > evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/input/P_unit_type_declared_before.sv <<'EOF
typedef int mytype;
function int f();
  mytype x;
  x = 9;
  return x;
endfunction
module m;
  initial $display("%0d", f());
endmodule
EOF
cat > evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/input/P_wildcard_local_no_prior_ref.sv <<'EOF
package p;
  int x = 99;
endpackage
module m;
  import p::*;
  int x = 2;
  initial $display("%0d", x);
endmodule
EOF
cat > evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/input/P_genhier_instantiated.sv <<'EOF
module top;
  if (1) begin : g
    int v;
  end
  initial begin
    top.g.v = 7;
    #1 $display("%0d", top.g.v);
  end
endmodule
EOF
cat > evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/input/P_for_generate_no_collision.sv <<'EOF'
module m;
  for (genvar i = 0; i < 0; i = i + 1) begin : g
    int v;
  end
  int h;
  initial begin
    h = 3;
    $display("%0d", h);
  end
endmodule
EOF
cat > evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/manifest.tsv <<'EOF'
case	top	kind	expected
N_unit_forward_var	m	negative	-
N_unit_forward_var_scoped	m	negative	-
N_unit_forward_type	m	negative	-
N_wildcard_then_local	m	negative	-
N_genhier_uninstantiated	top	negative	-
N_gen_collide_if1_var_before	m	negative	-
N_gen_collide_if1_var_after	m	negative	-
N_gen_collide_for	m	negative	-
P_unit_declared_before	m	positive	1 1
P_unit_type_declared_before	m	positive	9
P_wildcard_local_no_prior_ref	m	positive	2
P_genhier_instantiated	top	positive	7
P_for_generate_no_collision	m	positive	3
EOF
cat > evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/run.sh <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
RUN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOL_PREFIX=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb
IVERILOG="$TOOL_PREFIX/bin/iverilog"
VVP="$TOOL_PREFIX/bin/vvp"
mkdir -p "$RUN_DIR/logs" "$RUN_DIR/work"
printf 'case\tedition\tcompile_rc\trun_rc\tstdout\n' >"$RUN_DIR/results.tsv"
while IFS=$'\t' read -r case_name top kind expected; do
  [[ "$case_name" == case || -z "$case_name" ]] && continue
  for edition in 2017 2023; do
    stem="$RUN_DIR/logs/${case_name}-g${edition}"
    binary="$RUN_DIR/work/${case_name}-g${edition}.vvp"
    source="$RUN_DIR/input/${case_name}.sv"
    if timeout -k 2s 30s "$IVERILOG" "-g$edition" -B "$TOOL_PREFIX/lib/ivl" -s "$top" -o "$binary" "$source" >"$stem.compile.stdout" 2>"$stem.compile.stderr"; then compile_rc=0; else compile_rc=$?; fi
    run_rc=-
    actual=
    if [[ "$compile_rc" == 0 && "$kind" == positive ]]; then
      if timeout -k 2s 30s "$VVP" "$binary" >"$stem.run.stdout" 2>"$stem.run.stderr"; then run_rc=0; else run_rc=$?; fi
      actual="$(tr -d '\r' <"$stem.run.stdout" 2>/dev/null | sed -e '$s/[[:space:]]*$//' || true)"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$case_name" "$edition" "$compile_rc" "$run_rc" "$actual" >>"$RUN_DIR/results.tsv"
  done
done <"$RUN_DIR/manifest.tsv"
cat "$RUN_DIR/results.tsv"
EOF
cat > evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/run.sbatch <<'EOF'
#!/usr/bin/env bash
#SBATCH --job-name=a3-c23bound
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:15:00
#SBATCH --output=logs/%x-%j.out
set -euo pipefail
bash ./run.sh
EOF
chmod +x evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/run.sh evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/run.sbatch
sha256sum evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/input/*.sv evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/manifest.tsv evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/run.sh evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/run.sbatch > evidence/ieee1800-audit-c23-20261021/attempt-07-boundary-names/staging-sha256.txt