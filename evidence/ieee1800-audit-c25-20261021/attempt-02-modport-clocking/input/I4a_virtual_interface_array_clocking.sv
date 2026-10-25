interface SyncBus(input logic clk);
  wire a, b, c;
  clocking sb @(posedge clk);
    input a;
    output b;
    inout c;
  endclocking
endinterface
typedef virtual SyncBus VI;
task do_it(VI v);
  if (v.sb.a == 1)
    v.sb.b <= 0;
endtask
module top;
  logic clk = 0;
  SyncBus b1(clk), b2(clk);
  assign b1.a = 1;
  assign b2.a = 1;
  always #5 clk = ~clk;
  initial begin
    VI v[2] = '{b1, b2};
    @(b1.sb);
    do_it(v[0]);
    do_it(v[1]);
    #1 $display("%0b %0b", b1.b, b2.b);
    $finish;
  end
endmodule
