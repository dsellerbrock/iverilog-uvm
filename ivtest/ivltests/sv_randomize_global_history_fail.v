// IEEE 1800-2017/2023 18.4.2: exact domains still need cyclic history.
class scalar_leaf;
  randc bit [20:0] value;
  constraint c { value inside {0,1}; }
endclass
class array_leaf;
  randc bit [20:0] data[];
  constraint c { data.size()==1; foreach(data[i]) data[i] inside {0,1}; }
endclass
class unconstrained_leaf;
  randc bit [20:0] value;
endclass
class scalar_root;
  rand scalar_leaf c;
  function new(); c = new; endfunction
endclass
class array_root;
  rand array_leaf c;
  function new(); c = new; c.data=new[1]; c.data[0]=7; endfunction
endclass
class unconstrained_root;
  rand unconstrained_leaf c;
  function new(); c = new; endfunction
endclass
module main;
  scalar_root s = new;
  array_root a = new;
  unconstrained_root u = new;
  initial begin
    s.c.value=5; u.c.value=6;
    if (s.randomize() || s.c.value!=5) $fatal(1, "wide scalar history accepted or changed value");
    if (a.randomize() || a.c.data.size()!=1 || a.c.data[0]!=7)
      $fatal(1, "wide container history accepted or changed value");
    if (u.randomize() || u.c.value!=6) $fatal(1, "unmodeled history escaped the guard");
    $display("PASSED");
  end
endmodule
