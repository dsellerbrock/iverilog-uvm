module covgrp_db_corrupt;
  string save_db;
  string load_db;

  covergroup cg(int low, int high)
      with function sample(int state, int value, int sized_value);
    type_option.merge_instances = 1;
    cp_transition: coverpoint state {
      bins paths[] = (1[*2:3] => 4);
    }
    cp_dynamic: coverpoint value {
      bins values[] = {[low:high]};
    }
    cp_sized: coverpoint sized_value {
      bins values[2] = {[low:high]};
    }
  endgroup

  cg cov;

  initial begin
    if (!$value$plusargs("DB=%s", save_db)) begin
      $display("ERROR: missing +DB");
      $finish;
    end
    $set_coverage_db_name(save_db);
    if ($value$plusargs("LOADDB=%s", load_db))
      $load_coverage_db(load_db);
    if ($test$plusargs("QUERY_FIRST"))
      $display("PRE=%0.2f", $get_coverage());

    cov = new(0, 3);
    cov.sample(1, 0, 0);
    cov.sample(1, 0, 0);
    cov.sample(4, 0, 0);
    $display("COV=%0.2f", $get_coverage());
  end
endmodule
