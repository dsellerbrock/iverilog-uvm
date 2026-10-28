module top;
  reg [7:0] value;
  initial begin
    value = 8'h5a;
    #1 begin
      $display("PASSED");
      $finish;
    end
  end
endmodule
