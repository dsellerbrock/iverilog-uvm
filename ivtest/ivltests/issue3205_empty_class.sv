class empty_class;
endclass
class static_only_class;
  static int value;
endclass
module top;
  empty_class a;
  static_only_class b;
  int n;
  initial begin
    a = new;
    b = new;
    n = int'(a);
    n = int'(b);
  end
endmodule
