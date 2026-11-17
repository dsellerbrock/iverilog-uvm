// IEEE 1800-2023 36.12.1 Table 36-10: one of each variable kind the
// compatibility modes treat differently.
module top;
  reg r;
  reg [7:0] v;
  reg [7:0] mem [0:3];
  logic [3:0] la [0:1];
  integer i;
  integer ia [0:1];
  time t;
  time ta [0:1];
  real x;
  real xa [0:1];
  initial begin
    $probe_modes;
    $display("PASSED");
  end
endmodule
