// IEEE 1800-2017 18.7: reject the entire call if an inline item cannot lower.
// Historical regression name retained; successful partial solves are forbidden.
class item;
  rand int addr;
endclass

class driver;
  int lookup[3] = '{5, 10, 15};

  task run();
    item req = new;
    // The `addr inside {...}' item resolves normally; the foreach
    // item over `lookup' (a plain array outside item's own class)
    // does not; compilation must fail instead of applying only the range.
    void'(req.randomize() with {
        addr inside {[0:100]};
        foreach (lookup[i]) {
          addr != lookup[i];
        }
    });
    if (req.addr < 0 || req.addr > 100) begin
      $display("FAILED addr=%0d out of the resolvable range", req.addr);
      $finish;
    end
    $display("PASSED");
  endtask
endclass

module main;
  initial begin
    driver d = new;
    d.run();
  end
endmodule
