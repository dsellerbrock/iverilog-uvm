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
iverilog -g2012 -uvm -s top -o sim.vvp tb.sv
vvp sim.vvp +UVM_TESTNAME=my_test
```

(Options precede the source files, the ordering `iverilog` expects on every
platform; `getopt` on macOS/BSD does not reorder arguments the way glibc
does.)

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

The compile/link details of the umbrella live in one place,
[`uvm_dpi/build_uvm_dpi.sh`](../uvm_dpi/build_uvm_dpi.sh). It wraps
`iverilog-vpi` (which supplies the correct per-platform shared-object and PIC
flags and links against `-lvpi`):

* **Linux** — nothing extra; the undefined `sv*`/`vpi_*` imports bind lazily
  against `vvp` at load time. The installed `uvm_dpi.vpi` is loaded by the
  `-uvm` front end with full real DPI.
* **macOS** — a `<malloc.h>` → `<stdlib.h>` shim (the vendored `uvm_dpi.h`
  includes `<malloc.h>`, which is not a top-level header on macOS). Real DPI,
  same as Linux.

### Windows / MSYS2

Windows is a special case. A standalone global umbrella cannot serve real DPI
there, for two reasons a PE DLL cannot escape:

1. The umbrella references the per-design DPI-export dispatcher
   `m__uvm_report_dpi`, which exists only in the design's generated
   `.dpiexport.c` stub — a PE image must bind every symbol at link time and
   cannot late-bind it across separately loaded modules the way Linux/macOS
   do. (In this fork's umbrella that reference is in dead code — the vendor
   HDL/polling backends that call it are excluded — but the link still fails.)
2. `vvp` resolves a module's DPI imports by name via `GetProcAddress`, which
   only finds *exported* symbols; the large C++ umbrella does not auto-export
   on MinGW, and `iverilog-vpi` cannot pass the `-Wl,--export-all-symbols`
   that would fix it.

The supported real-DPI path on Windows is therefore the **per-test merged
module** used by the regression suite ([`.github/uvm_test.sh`](../.github/uvm_test.sh)):
it compiles the umbrella together with each design's DPI-export stub into one
module (so the dispatcher resolves internally), imports the whole `vvp.def`
from `vvp.exe`, links regex via `libsystre`/`tre` (a bare `-lregex` disagrees
on the `regex_t` layout and corrupts every wildcard match), and forces
`-Wl,--export-all-symbols`. That model verifies 209/0 real DPI on MINGW64,
UCRT64 and CLANG64.

Because the `-uvm` front end installs a single global umbrella rather than
merging per design, `make install` on Windows currently cannot produce a
working global umbrella: the build falls back, the installer ships the UVM
sources only, and `iverilog -uvm` runs under `UVM_NO_DPI` with a clear
diagnostic. Extending the global-umbrella front end to real DPI on Windows
(hand-rolling the umbrella link with the export/import flags above plus a
dead-code `m__uvm_report_dpi` stub) is tracked as follow-up; the manual
per-design flow in `uvm_test.sh` is the reference until then.

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
