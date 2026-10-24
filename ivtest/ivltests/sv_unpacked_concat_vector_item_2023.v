// IEEE 1800-2023 10.10.3: a vector concatenation is a legal,
// self-determined item of an unpacked array concatenation.
module main;
  int C[];

  initial begin
    C = {{8'h01, 8'h02}, 3};
    if (C.size() != 2 || C[0] != 258 || C[1] != 3) begin
      $display("FAILED: size=%0d C[0]=%0d C[1]=%0d",
               C.size(), C[0], C[1]);
      $finish(1);
    end
    $display("PASSED");
  end
endmodule
