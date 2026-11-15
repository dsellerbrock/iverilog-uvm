// Issue #3378 (IEEE 1800-2023 19.5.1, 19.5.1.1, type_option.distribute_first):
// with distribute_first the values are distributed to the bins first and the
// `with` filter applies afterwards. A bin the filter empties stays a bin; a
// filtered-out value hits no bin. A fixed-size array over 65536 bins keeps
// these rules (the filter's kept values become KEEP ranges of the family).
module top;
  int v;
  int failures = 0;

  covergroup big_cg;
    type_option.distribute_first = 1;
    option.per_instance = 1;
    // 140000 values, 2 per bin; values below 3 are kept.
    cs: coverpoint v { bins f[70000] = {[0:139999]} with (item < 3); }
    // A range filter with a hole; ignore_bins still drops bin 0 (#3306).
    cr: coverpoint v { bins f[70000] = {[0:139999]}
                         with (item inside {[0:99], [1000:1999]});
                       ignore_bins ig = {[0:1]}; }
  endgroup

  // The same rules within the limit, on the static path.
  covergroup small_cg;
    type_option.distribute_first = 1;
    option.per_instance = 1;
    cs: coverpoint v { bins f[4] = {[0:7]} with (item < 3); }
  endgroup

  task automatic check(string what, real got, real want);
    if (got < want - 1.0e-9 || got > want + 1.0e-9) begin
      $display("FAILED: %s = %0.10f, want %0.10f", what, got, want);
      failures += 1;
    end
  endtask

  big_cg b;
  small_cg s;
  initial begin
    b = new;
    s = new;
    v = 3;    b.sample(); s.sample();   // filtered out: no bin
    v = 2;    b.sample(); s.sample();   // bin 1 (values 2, 3)
    v = 500;  b.sample();               // cr: filtered out
    v = 1500; b.sample();               // cr: bin 750
    v = 50;   b.sample();               // cr: bin 25
    check("small cs", s.cs.get_inst_coverage(), 100.0 * 1 / 4);
    check("cs", b.cs.get_inst_coverage(), 100.0 * 1 / 70000);
    // cr: bin 0 carved by ignore_bins; bins 1 (v=2), 25 and 750 hit.
    check("cr", b.cr.get_inst_coverage(), 100.0 * 3 / 69999);
    if (failures == 0) $display("PASSED");
  end
endmodule
