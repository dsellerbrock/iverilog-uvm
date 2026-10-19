#!/usr/bin/env python3
"""Run JSON regression entries one at a time under the suite timeout driver."""
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[4])
manifest = Path(sys.argv[1])
output_dir = Path(sys.argv[2])
timeout = sys.argv[3]
ivtest = root / "ivtest"
timeout_driver = root / "scripts/run_with_timeout.py"
output_dir.mkdir(parents=True, exist_ok=True)
rows = [line.strip() for line in manifest.read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")]
if not rows:
    raise SystemExit(f"no tests in {manifest}")

results = []
for index, row in enumerate(rows, 1):
    name = row.split()[0]
    one_test = output_dir / f"{index:03d}-{name}.list"
    one_test.write_text(row + "\n")
    log_path = output_dir / f"{index:03d}-{name}.log"
    command = [sys.executable, str(timeout_driver), timeout, "--",
               sys.executable, "vvp_reg.py", str(one_test)]
    with log_path.open("w") as log:
        result = subprocess.run(command, cwd=ivtest, stdout=log,
                                stderr=subprocess.STDOUT, check=False)
    passed = result.returncode == 0
    results.append((name, result.returncode, passed))
    print(f"{name}: {'PASS' if passed else 'FAIL'} exit={result.returncode}")

summary = output_dir / "summary.txt"
summary.write_text("\n".join(f"{name} exit={code}" for name, code, _ in results) + "\n")
passed_count = sum(passed for _, _, passed in results)
print(f"JSON_RESULT: {passed_count}/{len(results)} passed")
raise SystemExit(0 if passed_count == len(results) else 1)
