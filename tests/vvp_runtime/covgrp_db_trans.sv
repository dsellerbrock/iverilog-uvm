module covgrp_db_trans;
  string save_db;
  string load_db;
  integer lo, hi;

  covergroup cg(int low, int high) with function sample(int value);
    type_option.merge_instances = 1;
    cp: coverpoint value {
      option.at_least = 2;
      bins arrayed[] = (low => high);
      bins scalar = (low => high);
    }
  endgroup

  cg cov;

  initial begin
    if (!$value$plusargs("DB=%s", save_db) ||
        !$value$plusargs("LO=%d", lo) || !$value$plusargs("HI=%d", hi)) begin
      $display("ERROR: missing transition database or bounds plusarg");
      $finish;
    end
    $set_coverage_db_name(save_db);
    if ($value$plusargs("LOADDB=%s", load_db))
      $load_coverage_db(load_db);
    if ($test$plusargs("QUERY_FIRST"))
      $display("PRE=%0.2f", $get_coverage());

    cov = new(lo, hi);
    cov.sample(lo);
    cov.sample(hi);
    $display("COV=%0.2f", $get_coverage());
  end
endmodule
