`timescale 1ns/1ns
module chk(input clk, input d);
  reg ns = 0, nh = 0;
  specify
    $setup(d, posedge clk, 3, ns);
    $hold(posedge clk, d, 2, nh);
  endspecify
endmodule

module main;
  reg clk = 0, d = 0;
  chk u(clk, d);
  initial begin
    #10 d = 1;
    clk = 1;
    #1;
    if (u.ns !== 0 || u.nh !== 1)
      $fatal(1, "FAIL ns=%b nh=%b", u.ns, u.nh);
    $display("PASS ns=%b nh=%b", u.ns, u.nh);
    $finish;
  end
endmodule
