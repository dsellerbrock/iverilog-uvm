module sv_embedded_covergroup_assign_outside_new_2017;
  class K;
    bit v;
    covergroup cv; coverpoint v; endgroup
    function new(); cv = new; endfunction
    function void f(); cv = new; endfunction
  endclass
  K k = new;
  initial k.f();
endmodule
