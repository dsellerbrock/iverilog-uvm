module top;
  initial begin
    for (int i = 0; i < 2; i++) begin
      $display("i=%0d", i);
    end
  end
endmodule
