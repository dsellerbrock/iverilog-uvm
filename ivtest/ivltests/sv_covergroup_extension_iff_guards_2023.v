class base_c;
  bit a, b;
  covergroup cg;
    a_cp: coverpoint a;
    b_cp: coverpoint b;
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  bit d, en;
  covergroup extends cg;
    cp_guard: coverpoint d iff (d && en);
    bin_guard_cp: coverpoint d { bins one = {1} iff (d && en); }
    cross_guard: cross a_cp, b_cp iff (d && en);
  endgroup : cg
endclass

module test;
  derived_c item;
  initial begin
    item = new;
    item.cg.sample();
  end
endmodule
