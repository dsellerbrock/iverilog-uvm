// Reproducer: a named sequence declared in BOTH arms of a conditional
// generate is rejected as a duplicate. Each generate block is its own
// scope and only one arm is ever elaborated, so this is legal.
//
//   error: duplicate sequence declaration `S1'.
//
// OpenTitan's prim_alert_sender does exactly this, declaring
// PingSigInt_S and AckSigInt_S in both gen_async_assert and
// gen_sync_assert.
//
// Root: pform_sva_declare_sequence (pform.cc) registers into
// sva_module_sequences, keyed by NAME alone with no scope component,
// and rejects a repeat. The map is cleared only at endmodule.
//
// A fix must keep rejecting the same two declarations at MODULE level
// with no generate -- that IS a genuine duplicate and errors correctly
// today.
module top;
  logic clk=0, p=0, n=0;
  if (1) begin : ga
    sequence S1; p == n [*2]; endsequence
  end else begin : gb
    sequence S1; p == n; endsequence
  end
endmodule
