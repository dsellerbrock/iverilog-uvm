class C #(int N = 3);
  typedef bit [N-1:0] T;
endclass
module top;
  int x = 9;
  initial begin
    if (C#()::T'(x) !== 3'b001) $fatal(1, "K3 expected 1");
    $display("PASS K3 value=%0d", C#()::T'(x));
  end
endmodule
