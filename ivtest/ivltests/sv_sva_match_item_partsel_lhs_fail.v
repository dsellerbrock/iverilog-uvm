// A sequence match-item assignment (`(bool, lhs = rhs)`) whose LHS is a
// part-select of an assertion-local variable -- ordinary
// `operator_assignment' syntax (IEEE 1800-2017/2023 A.2.10's
// `sequence_match_item ::= operator_assignment | ...', whose
// `variable_lvalue' includes indexed/part-selected targets like any
// other assignment) -- must not produce a raw, unhandled `syntax
// error'. Confirmed independently: slang (--std 1800-2017) accepts
// the part-select form, 0 errors.
//
// Real, unmodified Caliptra formal-verification source relies on
// exactly this shape (src/ecc/formal/properties/
// fv_montmultiplier_glue.sv assembles a wide accumulator RADIX bits
// at a time across several match steps, one part-select write per
// step: `(1'b1, fv_reg[RADIX-1:0] = ...)`).
//
// This does NOT yet correctly assign to only part of the local
// variable -- that needs a real read-modify-write blend the
// assertion-local variable model does not support today (see
// DISCOVERED_DEBT.md DD-035). Accepting the syntax without a correct
// lowering would silently produce wrong values, so instead the
// construct is accepted grammatically and the assignment is honestly
// reported as unsupported and dropped, keeping only the step's
// boolean gate condition (matching a bare `sva_bool_atom` with no
// local-variable side effect -- exactly what actually happens).
module main;
  bit clk = 0;
  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking

  property p1;
    logic [7:0] fv_reg;
    (1'b1, fv_reg[3:0] = 4'd5) ##1 (fv_reg[3:0] == 4'd5);
  endproperty
  ap: assert property (p1);

  property p2;
    logic [7:0] fv_reg2;
    (1'b1, fv_reg2[3] = 1'b1) ##1 (fv_reg2[3] == 1'b1);
  endproperty
  ap2: assert property (p2);
endmodule
