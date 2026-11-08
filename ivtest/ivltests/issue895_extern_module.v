// IEEE 1800-2017/2023 23.5: extern module declarations, with definitions
// that take the extern ports by (.*) or repeat a matching header.
extern module m (a,b,c,d);
extern module a #(parameter size = 8, parameter type TP = logic [7:0])
                (input [size:0] a, output TP b);
extern module r (input wire x, output wire y);
extern module n (p, q);

module m (.*);
  input a, b, c;
  output d;
  assign d = a & b & c;
endmodule

module a (.*);
  assign b = a[7:0] + 8'd1;
endmodule

module r (input wire x, output wire y);
  assign y = ~x;
endmodule

module n (p, q);
  input p;
  output q;
  assign q = p;
endmodule

module top;
  wire [8:0] a;
  logic [7:0] b;
  wire c, d, e, y, q;
  assign a = 9'h1fe;
  assign c = 1'b1;
  assign e = 1'b0;
  m mm (a[0], a[1], c, d);
  a aa (.*);
  r rr (e, y);
  n nn (c, q);
  initial begin
    #1;
    if (d !== 1'b0 || b !== 8'hff || y !== 1'b1 || q !== 1'b1)
      $display("FAILED d=%b b=%h y=%b q=%b", d, b, y, q);
    else
      $display("PASSED");
  end
endmodule
