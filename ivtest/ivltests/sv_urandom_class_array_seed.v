module top;
  class C; int x; endclass
  C values[2];
  initial begin
    values[0] = new();
    $display("%0d", $urandom(values[0]));
  end
endmodule
