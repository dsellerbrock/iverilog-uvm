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
  initial begin
    a = new;
    b = new;
`ifdef SV_COVERAGE_DB_2017
    $set_coverage_db_name("work/sv_coverage_db_2017.db");
`else
    $set_coverage_db_name("work/sv_coverage_db_2023.db");
`endif
    a.sample(0);
    b.sample(0);
    $display("PASSED");
  end
endmodule
