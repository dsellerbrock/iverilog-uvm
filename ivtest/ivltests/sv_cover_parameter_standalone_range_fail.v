// A standalone symbolic consecutive-repetition range is legal SystemVerilog,
// but it is outside the focused instance-sized cover lowering.  Until that
// composition is implemented, it must fail compilation loudly instead of
// silently using the parameter declaration defaults or dropping the cover.
module sv_cover_parameter_standalone_range_fail #(
  parameter int LO = 1,
  parameter int HI = 3
);
  logic clk;
  logic a;

  unsupported: cover property (@(posedge clk) a[*LO:HI]);
endmodule
