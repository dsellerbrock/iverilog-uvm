// IEEE 1800-2017 18.5.9/18.5.14.1; 2023 18.5.8/18.5.13.1.
class cycle_node;
  rand bit [2:0] value;
  rand cycle_node next_node;
  bit impossible;
  constraint hard_c {
    value inside {[2:3]};
    value == next_node.value;
    if (impossible) value == 7;
  }
  constraint soft_c { soft value == 2; }
endclass
module main;
  cycle_node r = new;
  cycle_node child = new;
  initial begin
    r.next_node = child;
    r.next_node.next_node = r;
    r.soft_c.constraint_mode(0);
    child.soft_c.constraint_mode(0);
    if (!r.randomize() || r.value != r.next_node.value)
      $fatal(1, "hard cycle rejected");
    r.soft_c.constraint_mode(1);
    child.soft_c.constraint_mode(1);
    repeat (10) begin
      if (!r.randomize()) $fatal(1, "soft cycle randomize failed");
      if (r.value != 2 || r.next_node.value != 2)
        $fatal(1, "cyclic soft preference was not applied to the whole graph");
    end
    r.impossible = 1;
    child.impossible = 1;
    if (r.randomize()) $fatal(1, "impossible soft cycle unexpectedly solved");
    if (r.value != 2 || child.value != 2)
      $fatal(1, "failed soft cycle changed object values");
    r.impossible = 0;
    child.impossible = 0;
    if (!r.randomize() || r.value != 2 || child.value != 2)
      $fatal(1, "soft cycle did not recover after failed solve");
    $display("PASSED");
  end
endmodule
