module r06_24b_real_cast_isolate;
  int result, iv;
  real rv;
  initial begin
    result = $cast(iv, 3.7);
    $display("REAL_SOURCE_DONE result=%0d iv=%0d", result, iv);
    result = $cast(rv, 7);
    $display("REAL_DEST_DONE result=%0d", result);
    $finish;
  end
endmodule
