// A dense two-variable 10-bit constraint must not build a complete Z3 model
// once per feasible value. adc_ctrl_filter_cfg has this exact min/max shape,
// repeated across 16 objects. Keep the workload fixed and bounded so the
// regression is also a stable wall-time benchmark for the enumeration path.
module sv_constraint_small_domain_probe;

  class filter_cfg;
    rand bit [9:0] min_v;
    rand bit [9:0] max_v;

    constraint min_le_max_c { min_v <= max_v; }
  endclass

  filter_cfg cfg[16];
  int failures;
  int distinct_pairs;

  initial begin
    bit [19:0] previous_pair;
    bit have_previous;

    for (int i = 0; i < 16; i++) begin
      cfg[i] = new;
      cfg[i].srandom(32'hadc00000 + i);
      if (!cfg[i].randomize()) begin
        $display("FAILED: cfg[%0d] randomize returned false", i);
        failures++;
      end else begin
        if (cfg[i].min_v > cfg[i].max_v) begin
          $display("FAILED: cfg[%0d] min=%0d > max=%0d",
                   i, cfg[i].min_v, cfg[i].max_v);
          failures++;
        end
        if (have_previous && {cfg[i].min_v, cfg[i].max_v} != previous_pair)
          distinct_pairs++;
        previous_pair = {cfg[i].min_v, cfg[i].max_v};
        have_previous = 1'b1;
      end
    end

    if (distinct_pairs == 0) begin
      $display("FAILED: all constrained results were identical");
      failures++;
    end

    if (failures == 0) begin
      $display("PASSED");
      $finish(0);
    end
    $finish(1);
  end

endmodule
