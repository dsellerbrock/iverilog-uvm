class base_c;
  covergroup cg with function sample(bit arg);
    base_cp: coverpoint arg;
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  covergroup extends cg;
    extension_cp: coverpoint arg;
  endgroup : cg
endclass

module test;
  derived_c derived_item;
  base_c item;
  initial begin
    derived_item = new;
    item = derived_item;
    item.cg.sample(1'b1);
  end
endmodule
