module s4_plain_static_always_comb;
  class C;
    static function bit f(input bit a); return ~a; endfunction
  endclass
  bit x;
  logic y;
  always_comb y = C::f(x);
  initial begin
    x = 0; #1; $display("S4 x=%0b y=%0b", x, y);
    x = 1; #1; $display("S4 x=%0b y=%0b", x, y);
    $finish;
  end
endmodule
