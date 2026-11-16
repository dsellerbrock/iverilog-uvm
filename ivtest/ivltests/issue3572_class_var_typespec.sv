module top;
  class Base; int x; endclass
  class Derived extends Base; endclass
  Base empty, obj;
  Derived derived;
  initial begin
    derived = new;
    obj = derived;
    #2 $finish;
  end
endmodule
