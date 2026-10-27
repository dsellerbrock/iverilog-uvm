# Clause 37 VPI object-model probe

The probe checks the normative object relationships for a top-level module, ports, a value parameter, a variable, and a child module instance. [`p37.sv`](../../../tests/1800_audit/c37/p37.sv) defines top `p37`, two ports (`a`, `y`), parameter `P=7`, variable `v[7:0]`, and child instance `u` of module `sub`. [`vpi_obj.c`](../../../tests/1800_audit/c37/vpi_obj.c) reports port direction/size, parameter value, variable size, child definition name, and both VPI parent-scope handles so the instance relationship is visible in raw output.

The names and numeric constants used by the probe (`vpiModule`, `vpiPort`, `vpiParameter`, `vpiVariables`, `vpiScope`, `vpiDirection`, `vpiDefName`, `vpiSize`, `vpiInput`, `vpiOutput`) are present in the pinned public header, so no fallback constants are used.

The paired edition run uses the pinned Icarus toolchain at `/home/dsell/toolchains/iverilog-fb584a25-20261020` (source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, 13.0-devel), one CPU, 1 GiB, and a five-minute Slurm limit. Each build/compile/run subprocess has a wall-clock timeout. The batch output records hashes, stdout/stderr, and exit statuses.
