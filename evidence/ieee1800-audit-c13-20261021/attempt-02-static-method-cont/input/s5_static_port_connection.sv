module s5_child(input logic i, output logic o);
  always_comb o = i;
endmodule

module s5_static_port_connection;
  class C;
    static function bit f(input bit a); return ~a; endfunction
  endclass
  logic x;
  logic y;
  s5_child u(.i(C::f(x)), .o(y));
  initial begin
    x = 0; #1; $display("S5 x=%0b y=%0b", x, y);
    x = 1; #1; $display("S5 x=%0b y=%0b", x, y);
    $finish;
  end
endmodule
