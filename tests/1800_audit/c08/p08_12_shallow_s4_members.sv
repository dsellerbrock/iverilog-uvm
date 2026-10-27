module top;
  class Inner; int value; endclass
  class Holder;
    int q[$];
    Inner h;
    static int s = 5;
  endclass
  Holder a, b;
  initial begin
    a = new; a.q.push_back(1); a.q.push_back(2); a.h = new; a.h.value = 7;
    b = new a; b.q[0] = 9; b.h.value = 11; b.s = 12;
    if (a.q[0] != 1 || b.q[0] != 9) $fatal(1, "S4 queue was not copied by value");
    if (a.h.value != 11) $fatal(1, "S4 nested handle was not copied shallowly");
    if (a.s != 12 || b.s != 12) $fatal(1, "S4 static property was not shared");
    $display("PASS S4 queue=%0d/%0d nested=%0d shared=%0d", a.q[0], b.q[0], a.h.value, a.s);
  end
endmodule
