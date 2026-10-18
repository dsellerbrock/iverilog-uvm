class base_c;
  bit a;
  covergroup cg;
    base_cp: coverpoint a;
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  logic [1:0] d;
  covergroup extends cg;
    extension_cp: coverpoint d + 1;
  endgroup : cg
endclass

module test;
  derived_c item;
  initial begin
    item = new;
    item.cg.sample();
  end
endmodule
