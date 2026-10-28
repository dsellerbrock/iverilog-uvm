module covgrp_db_static_trans;
  string save_db;
  string load_db;
  string sequence_name;

  covergroup cg with function sample(int value);
    type_option.merge_instances = 1;
    cp: coverpoint value {
`ifdef COVDB_ATLEAST2
      option.at_least = 2;
`endif
      bins ranged[] = (1[*2:3] => 4);
      bins rise = (0 => 1);
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

    cov = new;
    if (!$value$plusargs("SEQ=%s", sequence_name)) begin
      $display("ERROR: missing +SEQ");
      $finish;
    end
    if (sequence_name == "first") begin
      cov.sample(1);
      cov.sample(1);
      cov.sample(4);
    end else if (sequence_name == "second") begin
      cov.sample(1);
      cov.sample(1);
      cov.sample(1);
      cov.sample(4);
    end else if (sequence_name == "same") begin
      cov.sample(1);
      cov.sample(1);
      cov.sample(4);
    end
    $display("COV=%0.2f", $get_coverage());
  end
endmodule
