// REPRO -- NOT a passing test. Icarus reports:
//   warning: Constraint item in 'no_overlap' of class policy is not
//            representable in the constraint solver and is ignored
// and then DROPS the item, so the run passes only by luck: start_offset is
// left free in [0:1000] and lands outside [100:200] most of the time. The
// flakiness IS the silent weakening the warning exists to flag.
//
// This is uvm_mem_mam.svh:495 reduced -- `uvm_mem_mam_policy_no_overlap',
// the last non-collapse semantic-debt line in a minimal UVM compile.
// slang 11.0.448 accepts it under --std 1800-2017 and 1800-2023.
//
// See memory note constraint-foreach-object-queue for the value-slot lead.

// uvm_mem_mam shape: the foreach collection is a PROPERTY of the class being
// randomized, and the body reads a property of each element.
class region_t;
  int lo; int hi;
  function new(int l, int h); lo = l; hi = h; endfunction
endclass
class policy;
  rand int start_offset;
  region_t in_use[$];              // a property, not caller scope
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
    begin automatic region_t r = new(100, 200); p.in_use.push_back(r); end
    if (!p.randomize()) begin $display("FAILED: randomize returned 0"); errors++; end
    else if (p.start_offset >= 100 && p.start_offset <= 200) begin
      $display("FAILED: start_offset=%0d inside excluded range", p.start_offset); errors++;
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
