class base_c;
  bit a;
  covergroup cg;
    cp: coverpoint a;
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  bit data [0:1];
  bit idx;
  covergroup extends cg;
    x: cross data[idx], a;
  endgroup : cg
endclass

module test;
  derived_c d;
  base_c b;
  initial begin
    d = new;
    b = d;
    d.data[1] = 1;
    d.idx = 1;
    d.a = 1;
    b.cg.sample();
  end
endmodule
