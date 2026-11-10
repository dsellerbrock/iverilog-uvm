module tb;
  int i = -3;
  initial begin
    $display("%g %e", i * 1000000, i * 1000000);
    $finish;
  end
endmodule
