module top;
  bit v;
  real type_cg, type_cp;

  covergroup cg;
    cp_v: coverpoint v { bins lo = {0}; bins hi = {1}; }
  endgroup

  cg g = new;

  initial begin
    v = 1;
    g.sample();
    type_cg = cg::get_coverage();
    type_cp = cg::cp_v::get_coverage();
    if (type_cg != 50.0 || type_cp != 50.0)
      $display("FAILED ISSUE627_TYPE_COVERAGE group=%0.0f item=%0.0f",
               type_cg, type_cp);
    else
      $display("PASSED ISSUE627_TYPE_COVERAGE group=%0.0f item=%0.0f",
               type_cg, type_cp);
  end
endmodule
