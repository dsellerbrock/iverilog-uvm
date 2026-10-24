interface A_Bus(input logic clk);
  wire req, gnt;
  clocking sb @(posedge clk);
    input gnt;
    output req;
  endclocking
  modport STB (clocking sb);
endinterface
class Driver;
  virtual A_Bus.STB vs;
  function new(virtual A_Bus.STB vif);
    vs = vif;
  endfunction
  task run();
    @(vs.sb);
    vs.sb.req <= 1;
    wait (vs.sb.gnt == 1);
    $display("granted %0t", $time);
  endtask
endclass
module top;
  logic clk = 0;
  logic g = 0;
  A_Bus b1(clk);
  assign b1.gnt = g;
  always @(posedge clk) g <= b1.req;
  always #5 clk = ~clk;
  initial begin
    Driver d;
    d = new(b1);
    d.run();
    $finish;
  end
  initial #100 $fatal(1, "timeout");
endmodule
