// Issue #1202 (IEEE 1800-2023 19.5.1.1): the name of the containing
// coverpoint, filtered with `with`, may stand for its range list, also
// for arrayed bins (one bin per value, or N bins).
module top;
  bit [3:0] v;
  covergroup cg;
    cp: coverpoint v {
      bins lo[] = cp with (item < 2);
      bins mid[2] = cp with (item inside {[4:7]});
    }
  endgroup
  cg c;
  initial begin
    c = new;
    v = 0; c.sample();
    v = 1; c.sample();
    v = 4; c.sample();
    // lo[] has two bins (0, 1), both hit; mid[2] splits 4..7 in two, one hit.
    if (c.cp.get_inst_coverage() == 75.0)
      $display("PASSED");
    else
      $display("FAILED: coverage %0.2f, want 75.00", c.cp.get_inst_coverage());
  end
endmodule
