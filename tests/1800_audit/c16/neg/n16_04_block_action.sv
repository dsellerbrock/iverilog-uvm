module test;
  initial assert #0 (1'b0) else begin
    $display("A compound action block is not allowed");
  end
endmodule
