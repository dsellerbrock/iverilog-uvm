class base_c;
  bit a;
  bit x;
  covergroup cg;
    cp: coverpoint x iff (a & x) { bins hit = {1}; }
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  bit a;
  covergroup extends cg;
  endgroup : cg
endclass

module test;
  initial $display("unexpected acceptance");
endmodule
