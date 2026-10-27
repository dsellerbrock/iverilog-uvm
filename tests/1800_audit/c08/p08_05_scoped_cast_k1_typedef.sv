class C #(int N = 3);
  typedef bit [N-1:0] T;
endclass
module top;
  typedef C#(3)::T t3;
  int x = 9;
  t3 y;
  initial begin
    y = t3'(x);
    if (y !== 3'b001) $fatal(1, "K1 expected 1, got %0d", y);
    $display("PASS K1 value=%0d", y);
  end
endmodule
