// IEEE 1800-2017 18.5.10; IEEE 1800-2023 18.5.9.
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
  initial begin
    if (c.randomize() || c.a != 0 || c.b != 0 || c.child.value != 0)
      $fatal(1, "cyclic order passed or changed values");
    if (a.randomize() || a.value[0] != 0 || a.value[1] != 0 || a.child.value != 0)
      $fatal(1, "non-scalar order silently sampled or changed values");
    if (r.randomize() || r.a != 0 || r.b != 0 || r.cycle != 0 || r.child.value != 0)
      $fatal(1, "ordered randc silently sampled or changed values");
    $display("PASSED");
  end
endmodule
