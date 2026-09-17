// A crash, not a diagnostic-quality gap: `static`/`automatic' as a
// PREFIX qualifier before `task'/`function' (the class-method-only
// form, IEEE 1800-2017/2023 A.1.9's `class_item` qualifiers) used on
// an ordinary MODULE-scope task/function declaration was rejected with
// a raw, unhandled bison `syntax error' -- entering panic-mode error
// recovery from the very first (unmatched) token. On a real file with
// several such declarations plus other, unrelated content after them,
// this corrupted parser-internal generate-scheme bookkeeping badly
// enough to crash the compiler outright (SIGABRT via an `assert()`
// failure in `pform_endgenerate`, `pform.cc`) once recovery eventually
// reached a later, syntactically-unrelated construct.
//
// This is genuinely illegal SystemVerilog -- confirmed independently
// via slang, which rejects it too, with a specific diagnostic ("error:
// qualifiers are not allowed on out-of-block method definitions").
// Icarus's *rejection* was already correct; only the diagnostic's
// quality (opaque "syntax error") and the downstream crash were real
// problems. The fix accepts the qualifier syntactically as a new
// `module_item` alternative (reusing the ordinary task_declaration/
// function_declaration grammar wholesale, exactly as the already-
// working `class_item_qualifier_opt task_declaration' class-method
// form does) so bison never needs panic-mode recovery for this
// construct at all, then reports a specific, focused error instead of
// a raw syntax error -- the construct stays rejected, just safely.
//
// Real, unmodified OpenTitan RTL hits this directly and crashed
// (hw/ip/spi_device/pre_dv/tb/spid_upload_tb.sv, `static task host();`
// and `static task sw();` at module scope, among others).
module main;
  static task bad_task();
    $display("unreachable");
  endtask
endmodule
