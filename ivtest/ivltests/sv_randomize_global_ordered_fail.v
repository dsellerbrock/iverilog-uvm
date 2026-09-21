// IEEE 1800-2017/2023 18.4.2; 2017 18.5.10 / 2023 18.5.9.
class leaf;
  rand bit value;
endclass
class cyclic_root;
  rand bit a, b;
  rand leaf child;
  function new(); child = new; endfunction
  constraint c { solve a before b; solve b before a; child.value == b; }
endclass
class array_root;
  rand bit value[2];
  rand leaf child;
  function new(); child = new; endfunction
  constraint c { solve value[0] before value[1]; child.value == value[1]; }
endclass
class randc_root;
  rand bit a, b;
  randc bit cycle;
  rand leaf child;
  function new(); child = new; endfunction
  constraint c { solve a before b; child.value == b; cycle <= a; }
endclass
module main;
  cyclic_root c = new;
  array_root a = new;
  randc_root r = new;
  bit [1:0] seen;
  initial begin
    if (c.randomize() || c.a != 0 || c.b != 0 || c.child.value != 0)
      $fatal(1, "cyclic order passed or changed values");
    if (!a.randomize() || a.child.value != a.value[1])
      $fatal(1, "selected-element order failed or violated child relation");
    repeat (2) begin
      if (!r.randomize() || r.cycle > r.a || r.child.value != r.b)
        $fatal(1, "legal ordered randc failed or violated constraints");
      if (seen[r.cycle]) $fatal(1, "ordered randc repeated before cycle end");
      seen[r.cycle] = 1;
    end
    if (seen != 2'b11) $fatal(1, "ordered randc cycle incomplete");
    $display("PASSED");
  end
endmodule
