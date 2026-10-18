class base_c;
  bit [3:0] a;
  covergroup cg;
    cp: coverpoint a;
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  covergroup extends cg;
  endgroup : cg
endclass

module test;
  initial $display("unexpected acceptance");
endmodule
