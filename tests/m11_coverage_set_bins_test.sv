// IEEE 1800-2017 19.5 set expressions, coverpoint-derived bins, and
// default illegal/ignore bins. These are used directly by OpenTitan HMAC.
module m11_coverage_set_bins_test;
  int pass_count = 0;
  int fail_count = 0;

  task check(input string name, input bit ok);
    if (ok) pass_count++;
    else begin
      fail_count++;
      $display("FAIL: %s", name);
    end
  endtask

  class queue_set_c;
    int valid_q[$];
    int value;
    covergroup cg;
      cp: coverpoint value {
        bins values[] = valid_q;
      }
    endgroup
    function new();
      valid_q.push_back(2);
      valid_q.push_back(5);
      valid_q.push_back(9);
      cg = new;
    endfunction
    function void go(int v); value = v; cg.sample(); endfunction
    function real cov(); return cg.get_inst_coverage(); endfunction
  endclass

  class filtered_c;
    bit [3:0] value;
    covergroup cg;
      digest_size: coverpoint value {
        bins one  = {4'h1};
        bins two  = {4'h2};
        bins four = {4'h4};
        bins eight = {4'h8};
        bins invalid = digest_size with (!$onehot0(item));
      }
    endgroup
    function new(); cg = new; endfunction
    function void go(bit [3:0] v); value = v; cg.sample(); endfunction
    function real cov(); return cg.get_inst_coverage(); endfunction
  endclass

  class default_c;
    int value;
    covergroup illegal_cg;
      cp: coverpoint value {
        bins legal = {1};
        illegal_bins rest = default;
      }
    endgroup
    covergroup ignore_cg;
      cp: coverpoint value {
        bins kept = {7};
        ignore_bins rest = default;
      }
    endgroup
    function new(); illegal_cg = new; ignore_cg = new; endfunction
  endclass

  queue_set_c qs;
  filtered_c flt;
  default_c dflt;
  real r;

  initial begin
    qs = new;
    qs.go(2);
    r = qs.cov();
    check("queue_set_first", r > 33.0 && r < 34.0);
    qs.go(5);
    r = qs.cov();
    check("queue_set_second", r > 66.0 && r < 67.0);
    qs.go(9);
    check("queue_set_full", qs.cov() == 100.0);

    flt = new;
    flt.go(4'h1);
    check("source_filter_regular", flt.cov() == 20.0);
    flt.go(4'h0); // $onehot0 is true: invalid bin must not match.
    check("source_filter_excludes_zero", flt.cov() == 20.0);
    flt.go(4'h3); // More than one bit set: invalid bin matches.
    check("source_filter_invalid", flt.cov() == 40.0);

    dflt = new;
    dflt.value = 1;
    dflt.illegal_cg.sample();
    check("illegal_default_excludes_named", dflt.illegal_cg.get_inst_coverage() == 100.0);
    $display("EXPECT ONE ILLEGAL-DEFAULT ERROR NEXT");
    dflt.value = 2;
    dflt.illegal_cg.sample();
    check("illegal_default_not_counted", dflt.illegal_cg.get_inst_coverage() == 100.0);

    dflt.value = 3;
    dflt.ignore_cg.sample();
    check("ignore_default_suppresses", dflt.ignore_cg.get_inst_coverage() == 0.0);
    dflt.value = 7;
    dflt.ignore_cg.sample();
    check("ignore_default_named", dflt.ignore_cg.get_inst_coverage() == 100.0);

    if (fail_count == 0)
      $display("M11 COVERAGE SET BINS TEST: PASS (%0d/%0d)", pass_count, pass_count);
    else
      $display("M11 COVERAGE SET BINS TEST: FAIL (%0d passed, %0d failed)",
               pass_count, fail_count);
    $finish(0);
  end
endmodule
