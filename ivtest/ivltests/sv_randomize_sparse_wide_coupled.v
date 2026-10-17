class sparse_wide_coupled_uniformity;
  rand bit mode;
  rand bit [64:0] value;
  constraint c {
    if (mode) value inside {[65'd1:65'd256]};
    else value == 65'd0;
  }
endclass

class sparse_wide_coupled_unsat;
  rand bit [64:0] value;
  constraint c { value == 65'd1; value == 65'd2; }
endclass

class sparse_wide_over_tuple_cap;
  rand bit mode;
  rand bit [64:0] value;
  constraint c {
    if (mode) value inside {[65'd1:65'd1024]};
    else value == 65'd0;
  }
endclass

module main;
  integer mode_one_count = 0;
  sparse_wide_coupled_uniformity sample = new;
  sparse_wide_coupled_unsat impossible = new;
  sparse_wide_over_tuple_cap boundary = new;

  initial begin
    sample.srandom(416);
    repeat (32) begin
      if (!sample.randomize())
        $fatal(1, "sparse coupled randomize failed");
      if (sample.mode) begin
        if (sample.value < 65'd1 || sample.value > 65'd256)
          $fatal(1, "invalid mode-one tuple");
        mode_one_count++;
      end else if (sample.value != 65'd0) begin
        $fatal(1, "invalid mode-zero tuple");
      end
    end

    if (mode_one_count < 28)
      $fatal(1, "257 legal tuples sampled with biased mode count %0d/32",
             mode_one_count);

    impossible.value = 65'd23;
    if (impossible.randomize())
      $fatal(1, "unsatisfiable coupled constraints succeeded");
    if (impossible.value != 65'd23)
      $fatal(1, "failed randomize changed the original value");

    boundary.srandom(417);
    if (!boundary.randomize())
      $fatal(1, "over-cap sparse randomize failed");
    if (boundary.mode) begin
      if (boundary.value < 65'd1 || boundary.value > 65'd1024)
        $fatal(1, "over-cap result is outside its legal set");
    end else if (boundary.value != 65'd0)
      $fatal(1, "over-cap singleton result is outside its legal set");

    $display("PASSED");
  end
endmodule
