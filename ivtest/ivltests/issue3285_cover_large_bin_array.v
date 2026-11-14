// Issue #3285 (IEEE 1800-2023 19.5.1, 19.5.5): an open bin array over more
// than 65536 values keeps one counter per value hit instead of being
// dropped; ignore and illegal values are not bins of it.
module top;
  int v, s;
  covergroup cg_plain; cp: coverpoint v { bins big[] = {[0:99999]}; } endgroup
  covergroup cg_carve;
    cp: coverpoint v {
      bins big[] = {[0:99999]};
      ignore_bins ig = {[0:49999]};
      illegal_bins il = {[50000:59999]};
    }
  endgroup
  covergroup cg_atleast; option.at_least = 2; cp: coverpoint v { bins big[] = {[0:99999]}; } endgroup
  covergroup cg_signed; cp: coverpoint s { bins big[] = {[-50000:49999]}; } endgroup
  // The same carve-out for a constructor-dependent array.
  covergroup cg_ctor(int hi);
    cp: coverpoint v { bins big[] = {[0:hi]}; ignore_bins ig = {[0:49999]}; }
  endgroup
  cg_plain a = new; cg_carve b = new; cg_atleast c = new; cg_signed d = new;
  cg_ctor e = new(99999);
  integer fails = 0;
  task check(input real got, input real want, input string what);
    if (got < want - 1e-9 || got > want + 1e-9) begin
      $display("FAILED: %s coverage %0.6f, want %0.6f", what, got, want);
      fails = fails + 1;
    end
  endtask
  initial begin
    v = 3; a.sample(); v = 70000; a.sample();
    v = 60000; b.sample(); v = 10; b.sample();
    v = 7; c.sample(); c.sample(); v = 8; c.sample();
    s = -1; d.sample(); s = -49999; d.sample(); s = 49999; d.sample();
    v = 60000; e.sample(); v = 10; e.sample();
    check(a.cp.get_inst_coverage(), 100.0 * 2 / 100000, "plain");
    check(b.cp.get_inst_coverage(), 100.0 * 1 / 40000, "carve");
    check(c.cp.get_inst_coverage(), 100.0 * 1 / 100000, "at_least");
    check(d.cp.get_inst_coverage(), 100.0 * 3 / 100000, "signed");
    check(e.cp.get_inst_coverage(), 100.0 * 1 / 50000, "ctor carve");
    check(cg_plain::get_coverage(), 100.0 * 2 / 100000, "plain type");
    if (fails == 0) $display("PASSED");
  end
endmodule
