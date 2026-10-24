module sv_coverage_db;
  covergroup cg_a with function sample(int value);
    type_option.merge_instances = 1;
    option.at_least = 2;
    cp: coverpoint value { bins zero = {0}; bins one = {1}; }
  endgroup

  covergroup cg_b with function sample(int value);
    type_option.merge_instances = 1;
    option.at_least = 2;
    cp: coverpoint value { bins zero = {0}; bins one = {1}; }
  endgroup

  cg_a a;
  cg_b b;
  real coverage;
  initial begin
    a = new;
    b = new;
`ifdef SV_COVERAGE_DB_2017
    $load_coverage_db("work/sv_coverage_db_2017.db");
`else
    $load_coverage_db("work/sv_coverage_db_2023.db");
`endif
    a.sample(0);
    b.sample(0);
    coverage = $get_coverage();
    if ((coverage < 49.9) || (coverage > 50.1)) begin
      $display("FAILED coverage=%0.2f", coverage);
      $finish;
    end
    $display("PASSED");
  end
endmodule
