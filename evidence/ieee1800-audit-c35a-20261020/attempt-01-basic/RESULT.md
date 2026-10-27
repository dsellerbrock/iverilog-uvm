# Clause 35 basic DPI import/export result

Slurm job 3557 completed on DAN-DESKTOP in 1 second with exit 0 (1 CPU, 1 GiB requested). Each compile, shared-library link, and simulation had a 30-second timeout. Tool versions, binary/source/header hashes, both generated `.dpiexport.c` files, both `.so` files, and raw stdout/stderr are in [remote-3557](remote-3557/).

Build and run steps were:

```sh
iverilog -B "$IVL_ROOT/lib/ivl" -g2017 -o p35_basic.out p35_basic.sv
gcc -shared -fPIC -I "$IVL_ROOT/include/iverilog" -o libdpi.so dpi_basic.c p35_basic.out.dpiexport.c
vvp -d ./libdpi.so ./p35_basic.out
```

The same commands were run under `-g2023`, with a separate output directory and generated export stub. Compile, link, and runtime return codes were all 0 in both editions. Both produced the exact expected output:

```text
D1 5
D2 3.0
D3 hi bob
D4 7
D5 50
```

This confirms only the probed scalar imports, output argument, function export, and context import callback in §§35.5–35.7. Exported tasks, imported tasks, disabled calls, and other types/ABI forms remain unassessed. No new issue was found or filed.

Open/closed dedupe results for `"DPI-C"`, `export DPI`, `context import`, `svdpi`, and `35.` are in [`dedupe/`](dedupe/). No open issue directly covers this basic probe. Closed #13 is a broader, completed DPI phase; #505/#506 concern array ABI gaps; none duplicates a new gap from this passing result.
