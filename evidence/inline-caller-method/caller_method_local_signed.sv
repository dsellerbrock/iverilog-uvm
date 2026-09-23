// local:: selects the caller's handle despite a same-named target member, and
// a signed method result keeps its type (IEEE 1800-2017/2023 18.7.1, 18.5.12/18.5.11).
class cfg_c;
  int mode;
  function int get_size(); return mode + 1; endfunction
  function int neg(); return -mode; endfunction
  function bit [39:0] wide(); return 40'h80_0000_0005; endfunction
endclass

class item2;
  rand bit [2:0] lanes;
  rand int s;
  rand bit [39:0] w;
  cfg_c cfg;
endclass

class seq;
  cfg_c cfg;
  function int run(item2 it);
    return it.randomize() with {
      lanes == local::cfg.get_size();
      s == local::cfg.neg();
      w == local::cfg.wide();
    };
  endfunction
endclass

module top;
  seq s;
  item2 i2;
  initial begin
    s = new; s.cfg = new; s.cfg.mode = 3;
    i2 = new; i2.cfg = new; i2.cfg.mode = 1;
    if (s.run(i2) && i2.lanes == 4 && i2.s == -3 && i2.w == 40'h80_0000_0005)
      $display("PASSED");
    else $display("FAIL lanes=%0d s=%0d w=%h", i2.lanes, i2.s, i2.w);
  end
endmodule
