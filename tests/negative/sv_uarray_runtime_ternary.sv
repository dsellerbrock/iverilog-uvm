// Companion to ivltests/sv_uarray_const_ternary: allowing a conditional
// over WHOLE unpacked arrays with a constant condition must NOT be
// mistaken for general support.
//
// With a run-time condition both arms would have to be evaluated and
// blended, and there is no run-time mux for a whole unpacked array --
// the code generator aborts on `lwid == ivl_signal_width(lsig)'. This
// must be rejected loudly rather than compiled into that abort.
module sv_uarray_runtime_ternary;
  logic sel;
  typedef logic [1:0][31:0] k_t;
  k_t a [2];
  k_t b [2];
  k_t d [2];
  always_comb d = sel ? a : b;
endmodule
