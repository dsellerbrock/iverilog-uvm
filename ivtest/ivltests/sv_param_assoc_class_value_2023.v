class sv_param_assoc_class #(int Values[string] = '{"one":7, default:-1});
  function int get_one();
    return Values["one"];
  endfunction

  function int get_absent();
    return Values["absent"];
  endfunction
endclass

module sv_param_assoc_class_value_2023;
  sv_param_assoc_class #('{"one":7, "two":8, default:-1}) first;
  sv_param_assoc_class #('{"one":9, "two":8, default:-1}) different;
  sv_param_assoc_class #('{"two":8, "one":7, default:-1}) same;

  initial begin
    first = new;
    different = new;
    same = new;
    if (first.get_one() != 7 || first.get_absent() != -1)
      $fatal(1, "class associative parameter value use");
    if (type(first) != type(same) || type(first) == type(different))
      $fatal(1, "associative parameter specialization identity");
    $display("PASSED");
  end
endmodule
