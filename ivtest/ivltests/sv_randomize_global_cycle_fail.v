// IEEE 1800-2017 18.5.9/18.5.14.1; 2023 18.5.8/18.5.13.1.
class cycle_node;
  rand bit [2:0] value;
  rand cycle_node next_node;
  constraint hard_c { value inside {[2:3]}; value == next_node.value; }
  constraint soft_c { soft value == 2; }
endclass
module main;
  cycle_node r = new;
  cycle_node child = new;
  bit [2:0] saved;
  initial begin
    r.next_node = child;
    r.next_node.next_node = r;
    r.soft_c.constraint_mode(0);
    child.soft_c.constraint_mode(0);
    if (!r.randomize() || r.value != r.next_node.value)
      $fatal(1, "hard cycle rejected");
    saved = r.value;
    r.soft_c.constraint_mode(1);
    child.soft_c.constraint_mode(1);
    if (r.randomize()) $fatal(1, "unsupported soft cycle silently accepted");
    if (r.value != saved || r.next_node.value != saved)
      $fatal(1, "soft cycle failure changed values");
    $display("PASSED");
  end
endmodule
