// REPRO -- NOT a passing test. Icarus reports:
//   warning: constraint `foreach (devs[...].addr_ranges[...]) { ... }'
//            could not be translated and is being ignored
//
// This is xbar_tl_host_seq.sv:52 reduced: a constraint foreach whose target
// is a NESTED, INDEXED path rather than a simple identifier. PEConstraintForeach
// does represent the hierarchical form (array_name[prefix].member[loop_vars]),
// so the gap is in resolving/emitting it, not in parsing.
//
// Narrowed by elimination -- each of these was tested and WORKS, so none is
// the gap: constraint if/else; an indexed class-handle element's property in
// a constraint; `inside' with range bounds from a nested indexed property.
// slang 11.0.448 accepts this file under both editions.

// The real xbar_tl_host_seq.sv:52 shape: a constraint foreach whose target is
// a NESTED, INDEXED path -- xbar_devices[device_id].addr_ranges[i] -- rather
// than a simple identifier.
class range_t;
  int start_addr; int end_addr;
  function new(int s, int e); start_addr = s; end_addr = e; endfunction
endclass
class dev_t;
  range_t addr_ranges[$];
  function new();
    begin automatic range_t r = new(100, 200); addr_ranges.push_back(r); end
  endfunction
endclass
class item;
  rand int a_addr;
endclass
module main;
  item req; dev_t devs[$];
  int did = 0;
  int errors = 0;
  initial begin
    req = new();
    begin automatic dev_t d = new(); devs.push_back(d); end

    // foreach over a nested indexed path, excluding every device range
    if (!req.randomize() with {
          a_addr inside {[0:1000]};
          foreach (devs[did].addr_ranges[i]) {
            !(a_addr inside {[devs[did].addr_ranges[i].start_addr :
                              devs[did].addr_ranges[i].end_addr]});
          }
        }) begin
      $display("FAILED: randomize returned 0"); errors++;
    end else if (req.a_addr >= 100 && req.a_addr <= 200) begin
      $display("FAILED: a_addr=%0d is inside the excluded range", req.a_addr); errors++;
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
