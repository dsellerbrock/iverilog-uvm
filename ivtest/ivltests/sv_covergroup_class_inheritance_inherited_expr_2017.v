class base_c;
  bit [1:0] a;
  covergroup cg;
    option.per_instance = 1;
    cp: coverpoint a + 1 { bins one = {1}; bins two = {2}; }
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
