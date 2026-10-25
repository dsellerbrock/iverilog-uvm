module issue859_sized_vector_array_concat;
  int C[];
  int vector_control = {8'h01, 8'h02};

  initial begin
    C = {{8'h01, 8'h02}, 3};

    if (C.size() != 2 || C[0] != 258 || C[1] != 3) begin
      $display("FAIL: C size=%0d values=%0d,%0d", C.size(), C[0], C[1]);
      $fatal(1);
    end
    if (vector_control != 258) begin
      $display("FAIL: vector=%0d", vector_control);
      $fatal(1);
    end
    $display("PASS: C=258,3 vector=258");
  end
endmodule
