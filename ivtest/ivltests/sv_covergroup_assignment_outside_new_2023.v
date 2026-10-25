class embedded_cg_assignment;
  bit value;
  covergroup cg;
    coverpoint value;
  endgroup

  function new();
    cg = new;
  endfunction

  function void reassign();
    cg = new;
  endfunction
endclass

module top;
  embedded_cg_assignment item = new;
endmodule
