// Issue #3306 (IEEE 1800-2023 19.5.1, 19.5.5): a fixed-size bin array
// needing more than 65536 counters is kept. Its values are distributed to
// the bins in order, then ignore/illegal values are removed; a bin left
// with no value is no bin, and every other bin keeps its place.
module top;
  int v;
  int failures = 0;

  covergroup cg(int hi);
    option.per_instance = 1;
    // 140000 values, 2 per bin.
    cs: coverpoint v { bins f[70000] = {[0:139999]}; ignore_bins ig = {[0:1]}; }
    // Bin 1 keeps value 3, so it is still a bin.
    c2: coverpoint v { bins f[70000] = {[0:139999]}; ignore_bins ig = {[0:2]}; }
    // Duplicate values; the 3 remainder values go to the last bin.
    c3: coverpoint v { bins f[70000] = {[0:139999], 1, 4, 7};
                       illegal_bins il = {[3:5]}; }
    // Bins 1..4 are emptied.
    c4: coverpoint v { bins f[70000] = {[0:139999]}; ignore_bins ig = {[2:9]}; }
    // Constructor-dependent values.
    cd: coverpoint v { bins f[70000] = {[0:hi]}; ignore_bins ig = {[0:1]}; }
    x:  cross c4, cs;
  endgroup

  // Within the limit the static path applies the same rules.
  covergroup small_cg;
    option.per_instance = 1;
    cs: coverpoint v { bins f[4] = {[0:7]}; ignore_bins ig = {[0:1]}; }
    c3: coverpoint v { bins f[4] = {[0:7], 1, 4, 7}; illegal_bins il = {[3:5]}; }
  endgroup

  task automatic check(string what, real got, real want);
    if (got < want - 1.0e-9 || got > want + 1.0e-9) begin
      $display("FAILED: %s = %0.10f, want %0.10f", what, got, want);
      failures += 1;
    end
  endtask

  cg e;
  small_cg s;
  initial begin
    e = new(139999);
    s = new;
    v = 2;  e.sample(); s.sample();
    v = 12; e.sample();
    check("cs", e.cs.get_inst_coverage(), 100.0 * 2 / 69999);
    check("c2", e.c2.get_inst_coverage(), 100.0 * 1 / 69999);
    check("c3", e.c3.get_inst_coverage(), 100.0 * 2 / 69999);
    check("c4", e.c4.get_inst_coverage(), 100.0 * 1 / 69996);
    check("cd", e.cd.get_inst_coverage(), 100.0 * 2 / 69999);
    // v=2 is ignored by c4; v=12 hits (c4 bin 6, cs bin 6).
    check("x",  e.x.get_inst_coverage(),  100.0 * 1 / (69996.0 * 69999.0));
    check("small cs", s.cs.get_inst_coverage(), 100.0 * 1 / 3);
    check("small c3", s.c3.get_inst_coverage(), 100.0 * 1 / 3);
    if (failures == 0) $display("PASSED");
  end
endmodule
