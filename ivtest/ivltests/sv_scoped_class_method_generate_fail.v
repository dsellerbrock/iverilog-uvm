// IEEE 1800-2017 8.24: a generate block is not the declaration scope of a
// module class. Reject the misplaced body without corrupting generate state.
module test;
  class local_c;
    extern function int read();
  endclass

  if (1) begin : generated_scope
    function int local_c::read();
      return 1;
    endfunction
  end
endmodule
