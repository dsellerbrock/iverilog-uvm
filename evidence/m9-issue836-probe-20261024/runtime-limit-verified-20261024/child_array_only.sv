class ch; rand bit [3:0] r; endclass
class d;
  rand ch c; rand bit [3:0] x, a[2]; bit [3:0] state = 1;
  function new(); c = new; endfunction
  function bit [3:0] f(); return state; endfunction
  constraint dist_c { foreach (a[i]) a[i] dist {5 := 1}; }
endclass
module main;
  d p = new;
  initial if (p.randomize()) $display("PASSED"); else $display("FAILED");
endmodule
