class base_c;
  bit [1:0] a;
  covergroup cg;
    cp_add: coverpoint a + 1;
    cp_paren: coverpoint ((a));
    cp_select: coverpoint a[0];
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  bit a;
  covergroup extends cg;
  endgroup : cg
endclass

module test;
  derived_c item;
  initial begin
    item = new;
    item.a = 0;
    item.cg.sample();
    $display("unexpected acceptance");
  end
endmodule
