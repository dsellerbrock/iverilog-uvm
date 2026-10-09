module sv_param_assoc_override #(
  parameter int Values[string] = '{"default":0}
) ();
  initial begin
    if (Values["override"] != 31 || Values["absent"] != -2)
      $fatal(1, "module associative parameter override");
  end
endmodule

module sv_param_assoc_value_2023 #(
  parameter int Values[string] = '{"one":7, default:-1},
  parameter string Names[int] = '{-2:"minus-two", 5:"five", default:"missing"},
  parameter int AnyKeys[*] = '{3:30, -2:-20, default:0}
) ();
  sv_param_assoc_override #('{"override":31, default:-2}) overridden();

  initial begin
    if (Values["one"] != 7 || Values["absent"] != -1)
      $fatal(1, "module associative parameter string keys/default");
    if (Names[-2] != "minus-two" || Names[5] != "five"
        || Names[9] != "missing")
      $fatal(1, "module associative parameter integral keys/default");
    if (AnyKeys[3] != 30 || AnyKeys[-2] != -20 || AnyKeys[8] != 0)
      $fatal(1, "module associative parameter wildcard keys/default");
    $display("PASSED");
  end
endmodule
