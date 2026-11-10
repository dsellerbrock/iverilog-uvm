module issue2796_wildcard_handle_eq;
  class base;
  endclass

  class derived extends base;
  endclass

  base a, b, c;

  initial begin
    a = new;
    b = a;
    c = new;
    if (!(a ==? b) || (a !=? b)) $fatal(1, "same handles");
    if ((a ==? c) || !(a !=? c)) $fatal(1, "different handles");
    if ((a ==? null) || !(a !=? null)) $fatal(1, "handle and null");
    a = null;
    if (!(a ==? null) || (a !=? null)) $fatal(1, "null handle");
    if (!(null ==? null) || (null !=? null)) $fatal(1, "null literals");
    if (!(null ==? a) || (null !=? a)) $fatal(1, "null on left");
    if ((4'b10xz ==? 4'b10xx) !== 1'b1) $fatal(1, "integral wildcard");
    $display("PASS");
  end
endmodule
