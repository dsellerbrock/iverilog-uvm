// IEEE 1800-2017/2023 places no textual-order requirement between a
// concurrent_assertion_statement naming a property and that property's
// own declaration within the same module scope (confirmed independently:
// slang accepts the identical construct with 0 errors, 0 warnings). Real,
// unmodified Caliptra formal-verification sources rely on exactly this
// forward-reference shape (src/sha512/formal/properties/fv_constraints.sv,
// src/sha512_masked/formal/properties/fv_constraints.sv): an assume/assert
// naming a property declared LATER in the same module.
//
// Before this fix, sva_module_properties (which resolves a bare
// `assert/assume/cover property (name);' to its declaration) was
// populated in single-pass textual parse order, so a property declared
// after its first use was not yet registered when that use was reached --
// it silently fell through to ordinary signal-name resolution and failed
// with "Unable to bind wire/reg/memory `name'", exactly as if the name
// were genuinely undefined.
module main;
  bit clk = 0;
  bit a = 0, b = 1;
  int fails = 0;

  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking

  // Forward reference: used here, declared below.
  ap_fwd: assert property (no_conflict) else fails++;

  property no_conflict;
    !(a && b);
  endproperty

  // A second, ordinary-order assert of a DIFFERENT property must remain
  // unaffected by the deferral machinery.
  property a_implies_not_b;
    a |-> !b;
  endproperty
  ap_ordinary: assert property (a_implies_not_b) else fails++;

  initial begin
    // a=0,b=1: no_conflict holds (not both true); a_implies_not_b
    // vacuously holds (a is 0).
    @(posedge clk); #1;
    if (fails != 0) begin
      $display("FAIL after tick1, fails=%0d", fails);
      $finish;
    end

    // a=1,b=0: no_conflict holds (not both true); a_implies_not_b holds
    // (a true, !b true).
    a = 1;
    b = 0;
    @(posedge clk); #1;
    if (fails != 0) begin
      $display("FAIL after tick2, fails=%0d", fails);
      $finish;
    end

    $display("PASSED");
    $finish;
  end
endmodule
