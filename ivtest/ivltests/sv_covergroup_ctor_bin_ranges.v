// IEEE 1800-2023 19.3 and 19.5.1: non-ref covergroup constructor
// arguments are per-instance values and may define coverpoint bin ranges.
module top;
  covergroup cg(int limit) with function sample(int value);
    cp: coverpoint value {
      bins bounded = {[0:limit-1]};
    }
  endgroup

  // A bin may combine declaration-time constants and constructor-dependent
  // ranges.  The constructor-reference requirement applies to the bin as a
  // whole, not independently to every range pair.
  covergroup cg_mixed(int limit) with function sample(int value);
    cp: coverpoint value {
      bins mixed = {[0:0], [2:limit-1]};
    }
  endgroup

  // This is the exact OpenTitan AES fault-injection shape: an unsized bin
  // array has one logical bin for every value selected by the constructor.
  covergroup cg_arrayed(int limit) with function sample(int value);
    cp: coverpoint value {
      bins values[] = {[0:limit-1]};
    }
  endgroup

  // Unary plus is the only admitted transparent runtime wrapper.
  covergroup cg_plus(int limit) with function sample(int value);
    cp: coverpoint value {
      bins bounded = {[0:+limit]};
    }
  endgroup

  // OpenTitan's shared TL agent uses this precedence-sensitive expression.
  // Additive operators bind more tightly than shifts, so width 2 creates
  // [0:2] and width 3 creates [0:4].  Each object must retain its own range.
  covergroup cg_tl_source(int valid_source_width)
      with function sample(int source);
    option.per_instance = 1;
    cp: coverpoint source {
      bins valid_sources[] =
          {[0 : 2 << (valid_source_width - 1) - 1]};
    }
  endgroup

  cg narrow;
  cg wide;
  cg_mixed mixed_gap;
  cg_mixed mixed_static;
  cg_mixed mixed_dynamic;
  cg_arrayed array_narrow;
  cg_arrayed array_wide;
  cg_plus plus_bound;
  cg_tl_source tl_narrow;
  cg_tl_source tl_wide;

  initial begin
    narrow = new(2);
    wide = new(4);

    narrow.sample(3);
    wide.sample(3);
    if (narrow.get_inst_coverage() != 0.0)
      $fatal(1, "narrow instance used another instance's bin range");
    if (wide.get_inst_coverage() != 100.0)
      $fatal(1, "wide instance did not use its constructor-bound bin range");

    narrow.sample(1);
    if (narrow.get_inst_coverage() != 100.0)
      $fatal(1, "narrow instance did not use its constructor-bound bin range");
    if (wide.get_inst_coverage() != 100.0)
      $fatal(1, "wide instance coverage changed after sampling narrow");

    mixed_gap = new(4);
    mixed_static = new(4);
    mixed_dynamic = new(4);
    mixed_gap.sample(1);
    if (mixed_gap.get_inst_coverage() != 0.0)
      $fatal(1, "mixed-range bin incorrectly covered its gap");
    mixed_static.sample(0);
    if (mixed_static.get_inst_coverage() != 100.0)
      $fatal(1, "mixed bin dropped its static range pair");
    mixed_dynamic.sample(3);
    if (mixed_dynamic.get_inst_coverage() != 100.0)
      $fatal(1, "mixed bin dropped its constructor-dependent range pair");

    plus_bound = new(2);
    plus_bound.sample(2);
    if (plus_bound.get_inst_coverage() != 100.0)
      $fatal(1, "unary-plus constructor endpoint was dropped");

    array_narrow = new(2);
    array_wide = new(4);

    array_narrow.sample(3);
    array_wide.sample(3);
    if (array_narrow.get_inst_coverage() != 0.0)
      $fatal(1, "narrow arrayed instance accepted an out-of-range value");
    if (array_wide.get_inst_coverage() != 25.0)
      $fatal(1, "wide arrayed instance did not cover one of four bins");

    array_narrow.sample(1);
    array_wide.sample(1);
    if (array_narrow.get_inst_coverage() != 50.0)
      $fatal(1, "narrow arrayed instance did not cover one of two bins");
    if (array_wide.get_inst_coverage() != 50.0)
      $fatal(1, "wide arrayed instance did not cover two of four bins");

    array_narrow.sample(0);
    array_wide.sample(0);
    if (array_narrow.get_inst_coverage() != 100.0)
      $fatal(1, "narrow arrayed instance did not cover both bins");
    if (array_wide.get_inst_coverage() != 75.0)
      $fatal(1, "wide arrayed instance did not cover three of four bins");

    array_wide.sample(2);
    if (array_wide.get_inst_coverage() != 100.0)
      $fatal(1, "wide arrayed instance did not cover all four bins");

    tl_narrow = new(2);
    tl_wide = new(3);
    tl_narrow.sample(4);
    tl_wide.sample(4);
    if (tl_narrow.get_inst_coverage() != 0.0)
      $fatal(1, "narrow TL range accepted an out-of-range source");
    if (tl_wide.get_inst_coverage() != 20.0)
      $fatal(1, "wide TL range did not create five per-value bins");

    for (int i = 0; i <= 2; i++) tl_narrow.sample(i);
    for (int i = 0; i <= 3; i++) tl_wide.sample(i);
    if (tl_narrow.get_inst_coverage() != 100.0)
      $fatal(1, "narrow TL range did not cover all three bins");
    if (tl_wide.get_inst_coverage() != 100.0)
      $fatal(1, "wide TL range did not cover all five bins");

    $display("PASSED");
  end
endmodule
