module covgrp_db_accum;
  bit [1:0] value;
  string save_db;
  string load_db;
  integer fd;
  integer sample_value;

`ifdef COVDB_DYNAMIC
  covergroup cg(int lo, int hi);
`else
  covergroup cg;
`endif
    type_option.merge_instances = 1;
    cp: coverpoint value {
`ifdef COVDB_ATLEAST2
      option.at_least = 2;
`endif
`ifdef COVDB_DYNAMIC
`ifdef COVDB_SIZED
      bins values[2] = {[lo:hi]};
`else
      bins values[] = {[lo:hi]};
`endif
`else
      bins b0 = {0};
      bins b1 = {1};
      bins b2 = {2};
      bins b3 = {3};
`endif
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
`ifdef COVDB_DYNAMIC
    cov = new(0, 3);
`else
    cov = new;
`endif

    if ($test$plusargs("CHECK_EMPTY")) begin
      fd = $fopen(save_db, "r");
      if (fd) begin
        $display("ERROR: database existed before simulation end");
        $fclose(fd);
      end
    end

    if ($value$plusargs("S0=%d", sample_value)) begin
      value = sample_value;
      cov.sample();
    end
    if ($value$plusargs("S1=%d", sample_value)) begin
      value = sample_value;
      cov.sample();
    end
    $display("COV=%0.2f", $get_coverage());
  end
endmodule
