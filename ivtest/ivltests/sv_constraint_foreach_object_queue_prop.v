// IEEE 1800-2017/2023 18.5.8 with 18.3.
//
// A constraint may iterate a queue of CLASS HANDLES and read a scalar
// property of each element. UVM's uvm_mem_mam_policy_no_overlap does exactly
// this (uvm_mem_mam.svh:495):
//
//   constraint uvm_mem_mam_policy_no_overlap {
//     foreach (in_use[i]) {
//       !(start_offset <= in_use[i].Xend_offsetX && ...);
//     }
//   }
//
// The collection is NOT rand -- the elements are already-allocated regions --
// so each element property is a KNOWN value at solve time and is pinned as a
// constant rather than solved for.
//
// THIS TEST IS AN ENFORCEMENT PROOF, NOT A SMOKE TEST. It excludes 991 of the
// 1001 legal values, so an unenforced constraint fails with probability
// ~0.99 per draw; 20 draws makes a false pass impossible in practice. That
// matters because an earlier attempt at this feature removed the "constraint
// ignored" warning WITHOUT enforcing anything, and a weaker test passed it.
// Do not replace this with a narrow excluded band.

class region_t;
  int lo;
  int hi;
  function new(int l, int h); lo = l; hi = h; endfunction
endclass

class policy;
  rand int start_offset;
  region_t in_use[$];
  constraint no_overlap {
    start_offset inside {[0:1000]};
    foreach (in_use[i]) {
      !(start_offset inside {[in_use[i].lo : in_use[i].hi]});
    }
  }
endclass

module main;

  policy p;
  int errors = 0;

  initial begin
    p = new();
    begin automatic region_t r = new(10, 1000); p.in_use.push_back(r); end

    // Only [0:9] remains legal out of [0:1000].
    for (int k = 0; k < 20; ++k) begin
      if (!p.randomize()) begin
        $display("FAILED: randomize() returned 0 on draw %0d", k);
        errors += 1;
      end else if (p.start_offset < 0 || p.start_offset > 9) begin
        $display("FAILED: draw %0d gave start_offset=%0d, outside [0:9]",
                 k, p.start_offset);
        errors += 1;
      end
    end

    // A second region narrows the legal set further, proving the foreach
    // body is re-expanded against the CURRENT element count.
    begin automatic region_t r2 = new(0, 4); p.in_use.push_back(r2); end
    for (int k = 0; k < 10; ++k) begin
      if (!p.randomize()) begin
        $display("FAILED: randomize() returned 0 with two regions");
        errors += 1;
      end else if (p.start_offset < 5 || p.start_offset > 9) begin
        $display("FAILED: two-region draw gave %0d, outside [5:9]",
                 p.start_offset);
        errors += 1;
      end
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d error(s)", errors);
  end

endmodule
