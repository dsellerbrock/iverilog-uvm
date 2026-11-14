`timescale 1ns/1ns
module issue3225_clocking_indexed;
  bit clk = 0;
  logic [3:0] data = 0;
  integer lo = 0, hi = 3;
  integer up_time = -1, down_time = -1, edge_time = -1;
  always #5 clk = ~clk;
  clocking cb @(posedge clk);
    input data;
  endclocking
  initial begin
    @(cb);
    fork
      begin @(cb.data[lo +: 2]); up_time = $time; end
      begin @(cb.data[hi -: 2]); down_time = $time; end
      begin @(posedge cb.data[lo +: 2]); edge_time = $time; end
      begin
        #1 data = 4'b1000;
        #10 data = 4'b1001;
      end
    join
    if (up_time == 25 && down_time == 15 && edge_time == 25)
      $display("PASS");
    else
      $display("FAIL up=%0d down=%0d edge=%0d", up_time, down_time, edge_time);
    $finish(0);
  end
  initial begin
    #40;
    $display("FAIL timeout up=%0d down=%0d edge=%0d", up_time, down_time, edge_time);
    $finish(0);
  end
endmodule
