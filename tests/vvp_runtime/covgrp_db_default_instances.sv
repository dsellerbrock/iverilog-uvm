class coverage_instance;
  bit [1:0] value;
  int instance_weight;

  covergroup cg(int lo, int hi);
    option.weight = instance_weight;
`ifdef MERGE_ON
    type_option.merge_instances = 1;
`endif
    cp: coverpoint value {
      bins values[] = {[lo:hi]};
    }
  endgroup

  function new(input int weight);
    instance_weight = weight;
    cg = new(0, 3);
  endfunction

  task put(input bit [1:0] sample_value);
    value = sample_value;
    cg.sample();
  endtask
endclass

module covgrp_db_default_instances;
  coverage_instance holder;
  string save_db;
  string load_db;
  integer sample_value;
  integer instance_weight = 1;

  initial begin
    if (!$value$plusargs("DB=%s", save_db))
      $fatal(1, "missing +DB");
    if (!$value$plusargs("W=%d", instance_weight))
      instance_weight = 1;
    $set_coverage_db_name(save_db);
    if ($value$plusargs("LOADDB=%s", load_db)) begin
      $load_coverage_db(load_db);
      if ($test$plusargs("QUERY_FIRST"))
        $display("PRE=%0.2f", $get_coverage());
    end

    if ($value$plusargs("S0=%d", sample_value)) begin
      holder = new(instance_weight);
      holder.put(sample_value);
    end
    if ($value$plusargs("S1=%d", sample_value)) begin
      if (holder == null) holder = new(instance_weight);
      holder.put(sample_value);
    end
    if ($test$plusargs("DROP")) begin
      $display("FIRST=%0.2f", $get_coverage());
      holder = null;
      $display("RETIRED=%0.2f", $get_coverage());
    end
    if ($value$plusargs("S2=%d", sample_value)) begin
      if (holder == null) holder = new(instance_weight);
      holder.put(sample_value);
    end
    if ($value$plusargs("S3=%d", sample_value)) begin
      if (holder == null) holder = new(instance_weight);
      holder.put(sample_value);
    end
    $display("COV=%0.2f", $get_coverage());
  end
endmodule
