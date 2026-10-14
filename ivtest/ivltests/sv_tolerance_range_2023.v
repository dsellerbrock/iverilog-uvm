module sv_tolerance_range_2023;
  int center, value;
  logic [7:0] unsigned_center, unsigned_value;
  real real_center, real_value;
  int cg_value;

  class tolerance_dist;
    rand int absolute_value;
    rand int relative_value;
    rand int integral_value;
    constraint absolute_range { absolute_value dist {[10 +/- 2] := 1}; }
    constraint relative_range { relative_value dist {[100 +%- 10] := 1}; }
    constraint real_range { integral_value dist {[1.0 +%- 25.0] :/ 1}; }
  endclass

  tolerance_dist dist_check;

  covergroup tolerance_cg;
    cp: coverpoint cg_value { bins percent = {[100 +%- 10]}; }
  endgroup

  tolerance_cg cov = new;

  initial begin
    center = 7;
    value = 5;
    if (!(value inside {[center +/- 2]})) $fatal(1, "FAIL -- absolute low");
    value = 9;
    if (!(value inside {[center +/- 2]})) $fatal(1, "FAIL -- absolute high");
    value = 4;
    if (value inside {[center +/- 2]}) $fatal(1, "FAIL -- absolute outside");
    value = 7;
    case (value) inside
      [center +/- 2]: ;
      default: $fatal(1, "FAIL -- case-inside absolute");
    endcase
    value = 6;
    if (!(value inside {[center +/- 1.75]})) $fatal(1, "FAIL -- absolute truncation low");
    value = 8;
    if (!(value inside {[center +/- 1.75]})) $fatal(1, "FAIL -- absolute truncation high");
    value = 5;
    if (!(value inside {[center +/- -2]})) $fatal(1, "FAIL -- absolute negative tolerance low");
    value = 9;
    if (!(value inside {[center +/- -2]})) $fatal(1, "FAIL -- absolute negative tolerance high");
    value = 4;
    if (value inside {[center +/- -2]}) $fatal(1, "FAIL -- absolute negative tolerance outside");

    unsigned_center = 10;
    unsigned_value = 8;
    if (!(unsigned_value inside {[unsigned_center +/- 2]})) $fatal(1, "FAIL -- unsigned low");
    unsigned_value = 12;
    if (!(unsigned_value inside {[unsigned_center +/- 2]})) $fatal(1, "FAIL -- unsigned high");

    value = 6;
    if (!(value inside {[center +%- 25]})) $fatal(1, "FAIL -- relative truncated low");
    value = 8;
    if (!(value inside {[center +%- 25]})) $fatal(1, "FAIL -- relative truncated high");
    value = 5;
    if (value inside {[center +%- 25]}) $fatal(1, "FAIL -- relative truncated outside");
    value = 8;
    case (value) inside
      [center +%- 25]: ;
      default: $fatal(1, "FAIL -- case-inside relative");
    endcase
    value = 6;
    if (!(value inside {[center +%- -25]})) $fatal(1, "FAIL -- relative negative tolerance low");
    value = 8;
    if (!(value inside {[center +%- -25]})) $fatal(1, "FAIL -- relative negative tolerance high");
    value = 5;
    if (value inside {[center +%- -25]}) $fatal(1, "FAIL -- relative negative tolerance outside");

    center = -7;
    value = -8;
    if (!(value inside {[center +%- 25]})) $fatal(1, "FAIL -- negative relative low");
    value = -6;
    if (!(value inside {[center +%- 25]})) $fatal(1, "FAIL -- negative relative high");
    value = -9;
    if (value inside {[center +%- 25]}) $fatal(1, "FAIL -- negative relative outside");

    real_center = 7.0;
    real_value = 5.25;
    if (!(real_value inside {[real_center +%- 25.0]})) $fatal(1, "FAIL -- real relative low");
    real_value = 8.75;
    if (!(real_value inside {[real_center +%- 25.0]})) $fatal(1, "FAIL -- real relative high");
    real_value = 5.24;
    if (real_value inside {[real_center +%- 25.0]}) $fatal(1, "FAIL -- real relative outside");

    cg_value = 89;
    cov.sample();
    if (cov.get_inst_coverage() != 0.0) $fatal(1, "FAIL -- covergroup outside");
    cg_value = 90;
    cov.sample();
    if (cov.get_inst_coverage() != 100.0) $fatal(1, "FAIL -- covergroup tolerance bin");

    dist_check = new;
    repeat (8) begin
      if (!dist_check.randomize()) $fatal(1, "FAIL -- tolerance dist randomize");
      if (dist_check.absolute_value < 8 || dist_check.absolute_value > 12)
        $fatal(1, "FAIL -- absolute dist range");
      if (dist_check.relative_value < 90 || dist_check.relative_value > 110)
        $fatal(1, "FAIL -- relative dist range");
      if (dist_check.integral_value < 0.75 || dist_check.integral_value > 1.25)
        $fatal(1, "FAIL -- real dist range");
    end

    $display("PASS");
    $finish;
  end
endmodule
