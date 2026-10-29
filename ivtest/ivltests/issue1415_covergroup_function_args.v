function automatic int from_const_ref(const ref int value);
  return value;
endfunction

module issue1415_covergroup_function_args;
  covergroup good_cg(int limit);
    cp: coverpoint limit { bins selected = {from_const_ref(limit)}; }
  endgroup

  good_cg cg;
  initial begin
    cg = new(16);
    cg.sample();
    if (cg.get_coverage() != 100.0)
      $fatal(1, "const-ref function bin was not retained");
    $display("PASSED");
  end
endmodule
