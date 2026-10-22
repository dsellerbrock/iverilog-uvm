module test;
  initial begin
    $set_coverage_db_name(12345);
    $finish;
  end
endmodule
