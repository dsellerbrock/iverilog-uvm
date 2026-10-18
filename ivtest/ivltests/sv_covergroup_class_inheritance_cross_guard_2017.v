class base_c;
  bit a;
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
endmodule
