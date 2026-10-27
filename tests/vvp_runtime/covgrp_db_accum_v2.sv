module covgrp_db_accum;
  bit [2:0] value;
  string save_db;
  string load_db;
  integer sample_value;

`ifdef COVDB_DYNAMIC
  covergroup cg(int lo, int hi);
`else
  covergroup cg;
`endif
    type_option.merge_instances = 1;
    cp: coverpoint value {
`ifdef COVDB_DYNAMIC
`ifdef COVDB_MISMATCH
      bins different[] = {[lo:hi]};
`else
      bins values[] = {[lo:hi]};
`endif
`else
      bins b4 = {4};
      bins b5 = {5};
      bins b6 = {6};
      bins b7 = {7};
`endif
    }
  endgroup

`ifdef COVDB_DYNAMIC
  cg cov = new(4, 7);
`else
  cg cov = new;
`endif

  initial begin
    if (!$value$plusargs("DB=%s", save_db) ||
        !$value$plusargs("LOADDB=%s", load_db)) begin
      $display("ERROR: missing database plusarg");
      $finish;
    end
    $set_coverage_db_name(save_db);
    $load_coverage_db(load_db);
    if ($value$plusargs("S0=%d", sample_value)) begin
      value = sample_value;
      cov.sample();
    end
    $display("COV=%0.2f", $get_coverage());
  end
endmodule
