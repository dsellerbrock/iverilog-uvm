// IEEE 1800-2017 18.5.14.1/.2; IEEE 1800-2023 18.5.13.1/.2.
class soft_leaf;
  rand bit value;
  bit preference;
  constraint c { soft value == preference; }
endclass
class soft_root;
  rand soft_leaf first, second, last;
  function new();
    first = new; second = new; last = first;
    first.preference = 0; second.preference = 1;
  endfunction
  constraint link { first.value == second.value; }
  constraint parent { soft second.value == 1; }
endclass
class disable_root;
  rand soft_leaf child;
  function new(); child = new; child.preference = 0; endfunction
  constraint c { disable soft child.value; soft child.value == 1; }
endclass
module main;
  soft_root r = new;
  disable_root d = new;
  initial begin
    repeat (20) begin
      if (!r.randomize() || r.first.value != 1 || r.second.value != 1)
        $fatal(1, "parent soft did not override children");
      if (!d.randomize() || d.child.value != 1)
        $fatal(1, "disable soft removed a higher-priority preference");
    end
    r.parent.constraint_mode(0);
    repeat (20)
      if (!r.randomize() || r.first.value != 0 || r.second.value != 0)
        $fatal(1, "last alias did not supply child priority");
    if (!r.randomize() with { soft first.value == 1; } || r.first.value != 1)
      $fatal(1, "inline soft did not override contained soft");
    $display("PASSED");
  end
endmodule
