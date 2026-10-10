// IEEE 1800-2017/2023 18.4.2, 18.6.3: a constrained randc cycle must
// exhaust its legal values without repeats and preserve state on failure.
class wide_cycle_item;
  randc bit [20:0] value;
  bit impossible;
  constraint legal_values {
    value inside {[0:1024]};
    if (impossible) value == 1025;
  }
endclass

class over_cap_cycle_item;
  randc bit [20:0] value;
  constraint legal_values { value inside {[0:2048]}; }
endclass

module test;
  initial begin
    wide_cycle_item item;
    over_cap_cycle_item boundary;
    bit [1024:0] seen;
    bit [20:0] previous;
    item = new;
    boundary = new;
    item.srandom(32'h4201025);
    boundary.srandom(32'h4202049);
    seen = '0;

    for (int unsigned i = 0; i < 64; i++) begin
      if (i == 32) begin
        previous = item.value;
        item.impossible = 1;
        if (item.randomize() || item.value !== previous)
          $fatal(1, "infeasible draw changed randc value");
        item.impossible = 0;
      end
      if (!item.randomize())
        $fatal(1, "randc failed at draw %0d", i);
      if (item.value > 1024 || seen[item.value])
        $fatal(1, "randc repeated or escaped its domain at draw %0d", i);
      seen[item.value] = 1'b1;
    end
    if (boundary.randomize())
      $fatal(1, "domain beyond the exact randc cap unexpectedly succeeded");
    $display("PASSED");
  end
endmodule
