module covgrp_db_cross;
  string save_db;
  string load_db;
  integer lo, hi, left_value, right_value;

  covergroup cg(int low, int high)
      with function sample(bit [2:0] left, bit [2:0] right);
    type_option.merge_instances = 1;
    cp_left: coverpoint left { bins values[] = {[low:high]}; }
    cp_right: coverpoint right { bins values[] = {[low:high]}; }
    cx: cross cp_left, cp_right {
      bins diagonal = binsof(cp_left) intersect {2} &&
                      binsof(cp_right) intersect {2};
    }
  endgroup

  cg cov;

  initial begin
    if (!$value$plusargs("DB=%s", save_db) ||
        !$value$plusargs("LO=%d", lo) || !$value$plusargs("HI=%d", hi) ||
        !$value$plusargs("LEFT=%d", left_value) ||
        !$value$plusargs("RIGHT=%d", right_value)) begin
      $display("ERROR: missing cross database or sample plusarg");
      $finish;
    end
    $set_coverage_db_name(save_db);
    if ($value$plusargs("LOADDB=%s", load_db) &&
        !$test$plusargs("LOAD_AFTER"))
      $load_coverage_db(load_db);
    if ($test$plusargs("QUERY_FIRST"))
      $display("PRE=%0.2f", $get_coverage());

    cov = new(lo, hi);
    if ($value$plusargs("LOADDB=%s", load_db) &&
        $test$plusargs("LOAD_AFTER"))
      $load_coverage_db(load_db);
    cov.sample(left_value, right_value);
    $display("COV=%0.2f", $get_coverage());
  end
endmodule
