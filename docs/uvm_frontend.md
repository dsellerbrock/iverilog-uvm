# The UVM front end (`iverilog -uvm`)

This document describes the architecture of the supported UVM front end: how
`iverilog -uvm` and the installed toolchain make the standard UVM + DPI flow
work with no user-specified paths, the way a commercial simulator does. For
day-to-day usage see the [README](../README.md#running-a-uvm-testbench) and
the [UVM usage guide](uvm.md); this document is the *design* reference.

## Goal

Replace the plumbing-heavy invocation

```bash
g++ -shared -fPIC -I<prefix>/include/iverilog -I uvm-core/src/dpi \
    -o uvm_dpi.so uvm_dpi/uvm_dpi_iverilog.cc
iverilog -g2012 -I uvm-core/src -o sim.vvp uvm-core/src/uvm_pkg.sv tb.sv
vvp -d ./uvm_dpi.so sim.vvp +UVM_TESTNAME=my_test
```

with

```bash
iverilog -g2012 -uvm tb.sv -s top -o sim.vvp
vvp sim.vvp +UVM_TESTNAME=my_test
```

The user no longer needs to know where the UVM sources live, which include
directory to add, where the DPI C/C++ sources are, how the DPI library is
built, where it ends up, or which `vvp -M/-m/-d` arguments to pass. The
installed toolchain knows where its own resources are and wires them up.

## Installed layout

UVM resources are installed under the same toolchain root Icarus already uses
for its VPI modules and headers, `<libdir>/ivl<suffix>` (the compiler and
runtime both call this the *base*). No new discovery mechanism is introduced.

```
<prefix>/
    bin/
        iverilog
        vvp
        iverilog-vpi
    lib/
        ivl<suffix>/                 <- the "base" (a.k.a. VPI module dir)
            system.vpi, v2009.vpi, ...
            uvm_dpi.vpi              <- standard UVM DPI runtime (a VPI module)
            uvm/
                src/                 <- UVM SystemVerilog sources (uvm_pkg.sv, ...)
    include/iverilog<suffix>/
            svdpi.h, vpi_user.h, ... <- DPI/VPI headers (for user DPI)
```

* `uvm/src/` is a copy of the Accellera `uvm-core/src` tree the fork tracks.
* `uvm_dpi.vpi` is the fork's DPI umbrella
  ([`uvm_dpi/uvm_dpi_iverilog.cc`](../uvm_dpi/uvm_dpi_iverilog.cc)) built as a
  loadable VPI module and installed alongside `system.vpi`.

## Resource discovery (one mechanism)

Both tools resolve the base the way Icarus already does, so relocated and
custom-prefix installs work with no extra machinery:

1. the compiled-in install path (`IVL_ROOT`, from `configure`'s `--prefix`),
2. else a path derived from the executable's own location
   (`/proc/self/exe` on Linux, `_NSGetExecutablePath` on macOS,
   `GetModuleFileName` on Windows), stripping `bin/` and appending
   `lib/ivl<suffix>`.

From the base, the driver forms `<base>/uvm/src` (UVM sources) and
`<base>/uvm_dpi.vpi` (DPI runtime). `vvp` finds `uvm_dpi.vpi` through its own
VPI module search path, which defaults to the same base and honors
`IVERILOG_VPI_MODULE_PATH` and `-M`.

## Automatic compiler behavior

When `-uvm` is given, the driver (`driver/main.c`):

1. Resolves the UVM source directory (see *Overrides* below; default
   `<base>/uvm/src`).
2. Verifies `uvm_pkg.sv` is present, and errors clearly if not.
3. Adds the UVM source directory as an include directory (`-I`).
4. Injects `uvm_pkg.sv` ahead of the user's sources — unless the user already
   listed a `uvm_pkg.sv`, so it is never compiled twice.
5. Raises the generation to SystemVerilog (`-g2012`) if the user left it at a
   non-SV default, since UVM requires SystemVerilog. An explicit SV `-g` is
   kept.
6. Records the standard UVM DPI runtime as an auto-loaded module (see below),
   unless `--uvm-no-dpi`.

No UVM-specific compatibility macros are defined for the normal path: the
unmodified Accellera library compiles as-is on this fork.

The `-uvm` options are recognized by a small pre-pass over `argv` before the
normal `getopt` loop, because the single-character `getopt` cannot represent
them (and `-u` already means separate compilation).

## Automatic runtime behavior (Option A: metadata in the compiled program)

The DPI dependency is recorded *in the compiled program*, not requested on the
`vvp` command line. This reuses the existing module mechanism end to end:

```
iverilog -uvm
    -> driver writes  module:<base>/uvm_dpi.vpi  into the ivl config
        -> ivl collects it into the VPI_MODULE_LIST design flag
            -> tgt-vvp emits  :vpi_module "<base>/uvm_dpi.vpi";  into sim.vvp
                -> vvp loads it at startup (vpip_load_module)
```

So `sim.vvp` itself declares that it needs the UVM DPI module, and `vvp`
resolves and loads it with no `-M`/`-m`/`-d` from the user — exactly the way
`system.vpi` is already handled.

### DPI imports from a VPI module

The UVM DPI umbrella exports the C functions that UVM's `import "DPI-C"`
declarations bind to (`uvm_re_*`, `uvm_hdl_*`, `uvm_dpi_*`). Historically
`vvp` resolved DPI imports only against libraries loaded with `-d`. The
runtime now also makes a loaded VPI module's symbols available to DPI import
resolution (`vvp_dpi_register_lib`, called from `vpip_load_module`), so the
umbrella — loaded as an ordinary `:vpi_module` — supplies those imports with
no separate `-d` load. The umbrella carries an (empty) `vlog_startup_routines`
table so it loads through the standard module path; it registers no system
tasks of its own, it exists to publish the DPI symbols.

This keeps the coupling minimal: no new `.vvp` directive, no changes to the
ivl→tgt-vvp path, and the umbrella stays an external, independently rebuildable
module rather than being linked into `vvp`.

### Relocation and moving `sim.vvp`

The `:vpi_module` path baked into `sim.vvp` is the absolute path the driver
resolved *at compile time* from its own install root — the same convention
`system.vpi` uses. Consequences:

* Compiling from any directory, and under any `--prefix`, works: the path is
  recomputed each compile from the toolchain's resolved base (compiled-in or
  executable-relative), so a relocated toolchain stays correct after a rebuild
  of the program.
* Moving `sim.vvp` to another directory on the same machine works (the path is
  absolute).
* Moving `sim.vvp` to a machine without the toolchain does not carry the DPI
  runtime — recompile there, or load a UVM DPI module explicitly with
  `vvp -M<dir> -m uvm_dpi`.

## Overrides and escape hatches

The bundled UVM is the easy default, not the only option:

| Option | Effect |
| --- | --- |
| `--uvm-home=<path>` | Use the UVM library at `<path>` instead of the bundled one. `<path>` may contain `uvm_pkg.sv` directly or a `src/` subdirectory that does. Implies `-uvm`. |
| `$IVERILOG_UVM_HOME` | Same as `--uvm-home`, via the environment. |
| `--uvm-no-dpi` | Compile UVM's pure-SystemVerilog fallbacks; do not record the DPI module (defines `UVM_NO_DPI`). |
| `--uvm-version` | Print the bundled UVM version and exit. Also shown by `iverilog -V`. |

## Standard UVM DPI vs. user DPI

These are deliberately separate:

* **Standard UVM DPI** is infrastructure the toolchain owns: it is bundled,
  built, installed, discovered, and loaded automatically. Users never name it.
* **User DPI** (a testbench's own native code) stays explicit and unchanged.
  Compile it as before and load it with `vvp -d mylib.so`, or build a VPI
  module with `iverilog-vpi` and load it with `-m`. `-uvm` does not interfere
  with these; the manual `-M`/`-m`/`-d` flows and raw
  `-I …/uvm_pkg.sv` compilation continue to work exactly as before.

## Build and install

The UVM DPI umbrella is built and installed by `make install` — no separate
manual step. The build is best effort: if it fails (or the `uvm-core`
submodule is not checked out), the install still succeeds and `-uvm` degrades
to a clear diagnostic (and `--uvm-no-dpi` still works), rather than silently
shipping a broken configuration.

The per-platform compile/link quirks of the umbrella live in one place,
[`uvm_dpi/build_uvm_dpi.sh`](../uvm_dpi/build_uvm_dpi.sh), shared by
`make install` and the CI regression harness. It wraps `iverilog-vpi` (which
already supplies the correct per-platform shared-object and PIC flags and links
against `-lvpi`) and adds:

* **Linux** — nothing extra; the undefined `sv*`/`vpi_*` imports bind lazily
  against `vvp` at load time.
* **macOS** — a `<malloc.h>` → `<stdlib.h>` shim (the vendored `uvm_dpi.h`
  includes `<malloc.h>`, which is not a top-level header on macOS).
* **Windows/MSYS2** — an import library for `vvp`'s `sv*` exports plus
  `-lregex`, because a DLL must resolve every import at link time.

## Diagnostics

* Missing UVM package (e.g. bad `--uvm-home`): a clear compile-time error
  naming the path it looked for; non-zero exit.
* Missing UVM DPI runtime: a clear compile-time warning that names the module
  it expected and states it is falling back to `UVM_NO_DPI` — never a silent
  fallback, and never a raw linker/loader error.

## Regression coverage

[`.github/uvm_frontend_test.sh`](../.github/uvm_frontend_test.sh) validates the
whole flow on Linux and macOS in CI: a staged install into a temporary prefix
with the compiled-in root hidden (forcing executable-relative discovery), then
basic automatic UVM, real DPI genuinely loaded (proven by contrast against a
no-provider build), the manual override, `--uvm-no-dpi`, `--uvm-home`,
`--uvm-version`, and the missing-runtime / missing-package diagnostics — all
from a working directory outside the source tree.
