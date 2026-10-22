class C #(int N = 3);
  typedef bit [N-1:0] T;
endclass
module top;
  int x = 9;
  initial begin
    if (C#(3)::T'(x) !== 3'b001) $fatal(1, "K2 expected 1");
    $display("PASS K2 value=%0d", C#(3)::T'(x));
  end
endmodule
