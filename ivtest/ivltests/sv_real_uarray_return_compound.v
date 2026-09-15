// Compound assignment must read and write the selected word of an emitted
// real return array. Cover both constant and runtime-computed indices.
module sv_real_uarray_return_compound;
  typedef real real_pair_t[2];

  function automatic real_pair_t constant_index();
    constant_index = '{1.5, 2.5};
    constant_index[0] += 3.0;
  endfunction

  function automatic real_pair_t dynamic_index(input int index);
    dynamic_index = '{1.5, 2.5};
    dynamic_index[index] += 3.0;
  endfunction

  real_pair_t result;

  task automatic expect_result(input string where);
    if (result[0] != 4.5 || result[1] != 2.5)
      $fatal(1, "%s: wrong return: %g %g", where, result[0], result[1]);
  endtask

  initial begin
    result = constant_index();
    expect_result("constant index");
    result = dynamic_index(0);
    expect_result("dynamic index");
    $display("PASSED");
  end
endmodule
