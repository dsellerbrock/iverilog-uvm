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
  bit [1:0] a;
  covergroup extends cg;
  endgroup : cg
endclass

module test;
  initial $display("unexpected acceptance");
endmodule
