// IEEE1800-2017/2023 10.4: blocking updates are immediately visible;
// NBA values are evaluated now and committed in the NBA region.
module order_dut #(parameter MODE=0)(input clk, rst, output reg [7:0] i, q);
  always @(posedge clk or posedge rst) if (rst) begin i<=0; q<=0; end else begin
    if (MODE==0) begin i=1; q<=i; end
    if (MODE==1) begin i<=1; q<=i; end
    if (MODE==2) begin i=1; i<=2; q<=i; end
    if (MODE==3) begin i<=2; i=1; q<=i; end
  end
endmodule
module test;
  reg clk=0, rst=1;
  wire [7:0] i0,q0,i1,q1,i2,q2,i3,q3;
  order_dut #(0) u0(clk,rst,i0,q0);
  order_dut #(1) u1(clk,rst,i1,q1);
  order_dut #(2) u2(clk,rst,i2,q2);
  order_dut #(3) u3(clk,rst,i3,q3);
  initial begin
    #1 clk=1; #1 clk=0; rst=0; #1 clk=1; #1;
    if ({i0,q0,i1,q1,i2,q2,i3,q3} !== {8'd1,8'd1,8'd1,8'd0,8'd2,8'd1,8'd2,8'd1})
      $fatal(1,"order values %h %h %h %h %h %h %h %h",i0,q0,i1,q1,i2,q2,i3,q3);
    $display("PASSED"); $finish(0);
  end
endmodule
