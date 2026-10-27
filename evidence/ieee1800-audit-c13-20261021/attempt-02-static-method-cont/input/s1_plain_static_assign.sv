module s1_plain_static_assign;
  class C;
    static function bit f(input bit a); return ~a; endfunction
  endclass
  bit x;
  wire y;
  assign y = C::f(x);
  initial begin
    x = 0; #1; $display("S1 x=%0b y=%0b", x, y);
    x = 1; #1; $display("S1 x=%0b y=%0b", x, y);
    $finish;
  end
endmodule
