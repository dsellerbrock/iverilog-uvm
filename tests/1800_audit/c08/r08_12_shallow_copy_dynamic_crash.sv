module top;
  class Base; int value; endclass
  class Derived extends Base; int extra; endclass
  Base source, copied;
  Derived derived;
  initial begin
    derived = new;
    derived.value = 4;
    derived.extra = 9;
    source = derived;
    $display("BEFORE_COPY");
    copied = new source;
    $display("AFTER_COPY %0d", copied.value);
  end
endmodule
