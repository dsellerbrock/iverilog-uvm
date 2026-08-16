module main;
  logic clk;
  logic a;
  logic b;
  logic y;
  logic z;

  always_comb y = a ^ b;

  // An identically spelled source attribute must not spoof the internal
  // provenance bit and hide ordinary RTL from synthesis.
  (* _ivl_generated_verification *)
  always_comb z = a & b;

  property named_check;
    @(posedge clk) a |-> b;
  endproperty

  a0: assert property (named_check);
  u0: assume property (@(posedge clk) a |-> b);
  c0: cover property (@(posedge clk) a && b);

  (* ivl_synthesis_off *)
  initial begin
    clk = 1'b0;
    a = 1'b0;
    b = 1'b0;
    #1 a = 1'b1;
    b = 1'b1;
    #1 clk = 1'b1;
    #1;
    if (y !== 1'b0 || z !== 1'b1)
      $fatal(1, "synthesized data path was changed: y=%b z=%b", y, z);
    $display("PASSED");
  end
endmodule
