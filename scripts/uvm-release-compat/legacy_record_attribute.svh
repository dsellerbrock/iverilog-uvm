// Harness-only compatibility shim for scripts/uvm_release_matrix.py.
//
// uvm-1.1b and uvm-1.1c guard `uvm_record_attribute` with
// `ifdef QUESTA .. elsif VCS .. elsif INCA .. endif` and NO unguarded
// fallback branch at all (unlike uvm-1.1d, which added one): on a simulator
// that is none of those three, the macro is simply never defined, and
// uvm_tlm2_generic_payload.svh -- part of the library, unconditionally
// compiled with it, even though this harness's own smoke.sv never touches
// TLM2 -- fails to parse. This is a real omission in those two pinned
// archives, not something this fork disagrees with; a vendor's own
// toolchain would need to predefine one of QUESTA/VCS/INCA for the same
// releases to compile there too.
//
// This file is NEVER part of the normal `-uvm`/`--uvm-home` path (see
// docs/uvm_frontend.md: "No UVM-specific compatibility macros are defined
// for the normal path... the unmodified Accellera library compiles as-is").
// It is compiled only by uvm_release_matrix.py, only for the two release
// ids whose manifest entry names it, and only ahead of that release's own
// uvm_pkg.sv (see the script for how ordering is arranged). It defines
// nothing UVM does not already define for itself on a supported vendor
// simulator, changes no UVM source, and does not claim to be QUESTA/VCS/
// INCA. It routes to the same native, tested attribute-capture systf this
// fork already ships (U15, uvm_dpi/uvm_recording.cc) -- not a no-op stub --
// so a release compiled this way records real attribute data if it reaches
// do_record at runtime, not merely a parse-time patch.
`ifndef uvm_record_attribute
`define uvm_record_attribute(TR_HANDLE,NAME,VALUE) \
  $ivl_uvm_record_attribute(TR_HANDLE,NAME,VALUE);
`endif
