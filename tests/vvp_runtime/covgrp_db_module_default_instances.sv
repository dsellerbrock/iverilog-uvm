module covgrp_db_module_default_instances;
  bit value;
  covergroup cg_t;
    cp: coverpoint value { bins zero = {0}; bins one = {1}; }
  endgroup
  cg_t cg = new;
  string save_db;
  string load_db;
  integer sample_value;

  initial begin
    if (!$value$plusargs("DB=%s", save_db))
      $fatal(1, "missing +DB");
    $set_coverage_db_name(save_db);
    if ($value$plusargs("PRE_SAMPLE=%d", sample_value)) begin
      value = sample_value;
      cg.sample();
    end
    if ($value$plusargs("PRE_SAMPLE2=%d", sample_value)) begin
      value = sample_value;
      cg.sample();
    end
    if ($value$plusargs("LOADDB=%s", load_db)) begin
      $load_coverage_db(load_db);
      if ($test$plusargs("QUERY_FIRST"))
        $display("PRE=%0.2f", $get_coverage());
    end
    if ($value$plusargs("SAMPLE=%d", sample_value)) begin
      value = sample_value;
      cg.sample();
    end
    if ($value$plusargs("SAMPLE2=%d", sample_value)) begin
      value = sample_value;
      cg.sample();
    end
    $display("COV=%0.2f", $get_coverage());
  end
endmodule
