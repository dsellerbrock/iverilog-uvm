module top;
  class Cnt; static int ctors = 0, inits = 0; int k = bump();
    static function int bump(); inits++; return 5; endfunction
    function new(); ctors++; endfunction endclass
  class L; int val; L next; endclass
  Cnt c1, c2; L p;
  initial begin c1 = new; c1.k = 9; c2 = new c1;
    $display("%s no_ctor_no_init", (Cnt::ctors == 1 && Cnt::inits == 1 && c2.k == 9) ? "PASS" : "FAIL");
    p = new; p.next = new; p.next.next = new; p.next.next.val = 77;
    $display("%s chained", p.next.next.val == 77 ? "PASS" : "FAIL"); end
endmodule
