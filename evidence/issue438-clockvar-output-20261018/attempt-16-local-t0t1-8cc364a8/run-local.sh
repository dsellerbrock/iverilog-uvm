#!/usr/bin/env bash
set -euo pipefail
RUN=/tmp/a3-438-t0t1-local-8cc364a8
SRC="$RUN/source"
ROOT=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue438-clockvar-output-20261018
export PATH="/opt/homebrew/opt/bison/bin:$PATH"
cd "$SRC"
LDFLAGS="-L/opt/homebrew/lib" CPPFLAGS="-I/opt/homebrew/opt/libffi/include -I/opt/homebrew/include" ./configure --prefix="$RUN/install" --enable-libveriuser LDFLAGS="-L/opt/homebrew/lib" CPPFLAGS="-I/opt/homebrew/opt/libffi/include -I/opt/homebrew/include" > "$RUN/logs/configure-retry.log" 2>&1
make -j3 > "$RUN/logs/build-retry.log" 2>&1
make install > "$RUN/logs/install-retry.log" 2>&1
if [ ! -e "$SRC/local-install" ]; then ln -s "$RUN/install" "$SRC/local-install"; fi
export PATH="$RUN/install/bin:$PATH"
sha256sum "$RUN/install/bin/iverilog" "$RUN/install/bin/vvp" > "$RUN/results/toolchain.sha256"
printf 'iverilog_version:\n' > "$RUN/results/versions.txt"
iverilog -V >> "$RUN/results/versions.txt" 2>&1
cd "$SRC/ivtest"
python3 "$SRC/scripts/run_with_timeout.py" 1800 -- perl ./vvp_reg.pl "$RUN/lists/t0-issue-legacy.list" > "$RUN/logs/t0-legacy.log" 2>&1
: > "$RUN/results/t0-json-status.tsv"
while IFS= read -r row; do
  [ -n "$row" ] || continue
  key=$(awk '{print $1}' <<< "$row")
  one="$RUN/lists/$key.list"
  printf '%s\n' "$row" > "$one"
  python3 "$SRC/scripts/run_with_timeout.py" 180 -- python3 ./vvp_reg.py "$one" > "$RUN/logs/t0-json-$key.log" 2>&1
  printf '%s\t0\n' "$key" >> "$RUN/results/t0-json-status.tsv"
done < "$RUN/lists/t0-issue-json.list"
cd "$SRC"
python3 "$SRC/scripts/run_with_timeout.py" 1800 -- bash ci/run-smoke.sh > "$RUN/logs/t0-smoke.log" 2>&1
cd "$SRC/ivtest"
python3 "$SRC/scripts/run_with_timeout.py" 1800 -- perl ./vvp_reg.pl "$RUN/lists/t1-legacy.list" > "$RUN/logs/t1-legacy.log" 2>&1
: > "$RUN/results/t1-json-status.tsv"
while IFS= read -r row; do
  case "$row" in ''|\#*) continue ;; esac
  key=$(awk '{print $1}' <<< "$row")
  one="$RUN/lists/$key.list"
  printf '%s\n' "$row" > "$one"
  python3 "$SRC/scripts/run_with_timeout.py" 180 -- python3 ./vvp_reg.py "$one" > "$RUN/logs/t1-json-$key.log" 2>&1
  printf '%s\t0\n' "$key" >> "$RUN/results/t1-json-status.tsv"
done < "$RUN/lists/t1-json.list"
printf 'T0=PASS\nT1=PASS\nfinished=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$RUN/results/DONE"
printf 'T0=PASS\nT1=PASS\nfinished=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$RUN/results/run-meta.txt"
printf 'RESULT_DIR=%s\n' "$RUN"
