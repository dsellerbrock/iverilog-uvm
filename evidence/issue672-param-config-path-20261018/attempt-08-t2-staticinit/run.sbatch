#!/bin/bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-672-staticinit
#SBATCH --cpus-per-task=2
#SBATCH --mem=3G
#SBATCH --time=01:00:00
#SBATCH --output=logs/%x-%j.out
set -euo pipefail
run_dir="$SLURM_SUBMIT_DIR"
mkdir -p "$run_dir/source" "$run_dir/install" "$run_dir/results"
tar --warning=no-unknown-keyword -xzf "$run_dir/input/source.tar.gz" -C "$run_dir/source"
cd "$run_dir/source/source"
sh autoconf.sh >"$run_dir/results/autoconf.log" 2>&1
./configure --prefix="$run_dir/install" >"$run_dir/results/configure.log" 2>&1
/usr/bin/time -v -o "$run_dir/results/build.time" make -j2 >"$run_dir/results/build.log" 2>&1
make install >"$run_dir/results/install.log" 2>&1
export PATH="$run_dir/install/bin:$PATH"
printf 'source_commit=' > "$run_dir/results/source.txt"
cat "$run_dir/input/source-commit.txt" >> "$run_dir/results/source.txt"
printf 'iverilog_sha256=' >> "$run_dir/results/source.txt"
sha256sum "$run_dir/install/bin/iverilog" | awk '{print $1}' >> "$run_dir/results/source.txt"
mkdir -p "$run_dir/results/lists"
grep -E '^sv_generic_master_static_init(_2023)?[[:space:]]' ivtest/regress-sv.list > "$run_dir/results/lists/static-init-legacy.list"
grep -E '^(sv_generic_master_static_init(_2023)?|sv_param_class_(bare_default_typedef|nested_typedef|qualified_typedef_instance|scoped_typedef_only)_registry_static_init(_2017|_2023)?)[[:space:]]' ivtest/regress-vvp.list > "$run_dir/results/lists/static-init-json.list"
printf 'legacy_count=%s\njson_count=%s\n' "$(wc -l < "$run_dir/results/lists/static-init-legacy.list")" "$(wc -l < "$run_dir/results/lists/static-init-json.list")" > "$run_dir/results/counts.txt"
legacy_status=0
(cd ivtest && perl ./vvp_reg.pl "$run_dir/results/lists/static-init-legacy.list") >"$run_dir/results/static-init-legacy.log" 2>&1 || legacy_status=$?
json_status=0
(cd ivtest && python3 "$run_dir/source/source/scripts/run_with_timeout.py" 3600 -- python3 ./vvp_reg.py "$run_dir/results/lists/static-init-json.list") >"$run_dir/results/static-init-json.log" 2>&1 || json_status=$?
printf 'legacy_exit=%s\njson_exit=%s\n' "$legacy_status" "$json_status" > "$run_dir/results/status.txt"
exit $((legacy_status || json_status))
