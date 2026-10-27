module s2_parameterized_static_assign;
  class P #(parameter int W = 4);
    static function logic [W-1:0] f(input logic [W-1:0] a); return ~a; endfunction
  endclass
  logic [3:0] x;
  wire [3:0] y;
  assign y = P#(4)::f(x);
  initial begin
    x = 4'b0000; #1; $display("S2 x=%b y=%b", x, y);
    x = 4'b0011; #1; $display("S2 x=%b y=%b", x, y);
    $finish;
  end
endmodule
