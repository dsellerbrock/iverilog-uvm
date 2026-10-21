module test;
  int sample_value;
  covergroup cg;
    cp: coverpoint sample_value { bins zero = {0}; bins one = {1}; }
  endgroup

  cg coverage;

  initial begin
    coverage = new;
    if ($get_coverage() != 0.0)
      $fatal(1, "expected initial coverage 0, got %0f", $get_coverage());

    sample_value = 0;
    coverage.sample();
    if ($get_coverage() != 50.0)
      $fatal(1, "expected half coverage 50, got %0f", $get_coverage());

    sample_value = 1;
    coverage.sample();
    if ($get_coverage() != 100.0)
      $fatal(1, "expected full coverage 100, got %0f", $get_coverage());

    $set_coverage_db_name("audit-coverage.db");
    $load_coverage_db("audit-coverage.db");
    $display("PASS 19.9 coverage system tasks");
    $finish;
  end
endmodule
