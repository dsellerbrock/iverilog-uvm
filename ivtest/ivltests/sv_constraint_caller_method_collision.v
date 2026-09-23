// Target-first lookup (IEEE 1800-2017/2023 18.7): 'cfg' names the randomized
// object's own member, so the caller's same-named handle must not be used.
class cfg_c;
  int mode;
  function int get_size(); return mode + 1; endfunction
endclass

class item2;
  rand bit [2:0] lanes;
  cfg_c cfg;
endclass

// A receiver index may also name a target member ('i' below).
class item3;
  rand bit [2:0] lanes;
  rand bit [1:0] i;
endclass

class seq;
  cfg_c cfg;
  cfg_c cfgs[4];
  int i;
  function int run2(item2 it);
    return it.randomize() with { lanes == cfg.get_size(); };
  endfunction
  function int run3(item3 it);
    return it.randomize() with { lanes == cfgs[i].get_size(); };
  endfunction
endclass

module top;
  seq s;
  item2 i2;
  initial begin
    s = new; s.cfg = new; s.cfg.mode = 3;
    i2 = new; i2.cfg = new; i2.cfg.mode = 1;
    if (s.run2(i2) && i2.lanes == 2) $display("PASSED");
    else $display("FAIL lanes=%0d", i2.lanes);
  end
endmodule
