class base_c;
  bit [3:0] v;
  local const int k = 2;
  covergroup cg;
    cp: coverpoint v { bins b = {k + 1}; }
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
