`timescale 1ns/1ps
// FST dump-control exercise: every dump system task, many value changes,
// wide and real signals, so a serial and a threaded writer can be compared
// byte for byte.
module fst_ctl;
  reg clk = 0;
  reg [127:0] wide = 0;
  reg [7:0] cnt = 0;
  real r = 0.0;
  integer i;
  always #5 clk = ~clk;
  always @(posedge clk) begin
    cnt <= cnt + 1;
    wide <= {wide[126:0], wide[127] ^ cnt[0]} ^ {16{cnt}};
    r <= r + 0.25;
  end
  initial begin
    $dumpfile(`FILE);
    $dumpvars(0, fst_ctl);
    #20000 $dumpoff;
    #5000 $dumpon;
    #3000 $dumpall;
    $dumpflush;
    #40000 $dumplimit(200000);
    #200000 $finish;
  end
endmodule
