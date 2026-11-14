module top;
  class Inner; int x = 7; endclass
  class Outer;
    Inner child;
    int a[];
    static int shared = 9;
  endclass
  Outer n;
  initial begin
    n = new; n.child = new; n.a = new[1]; n.a[0] = 11;
    $check_prefix(0);
    n.child = null; $check_prefix(1);
    n = null; $check_prefix(2);
    n = new; n.child = new; $check_prefix(3);
    $finish;
  end
endmodule
