module issue3501_delayed_strength;
  reg a = 0, b = 1, enable = 1;
  integer d = 3;
  wire g, w, e, asym_g, asym_e, resolved_g, resolved_e, tri_g;
  wire highz_e, variable_delay;
  buf (weak1, weak0) #3 (g, a);
  assign (weak1, weak0) #3 w = a;
  assign (weak1, weak0) #3 e = a & b;
  buf (strong1, pull0) #3 (asym_g, a);
  assign (strong1, pull0) #3 asym_e = a & b;
  buf (weak1, weak0) #3 (resolved_g, a);
  assign (weak1, weak0) #3 resolved_e = a & b;
  pulldown (resolved_g), (resolved_e);
  bufif1 (weak1, weak0) #3 (tri_g, a, enable);
  assign (weak1, highz0) #3 highz_e = a & b;
  assign (weak1, weak0) #(d) variable_delay = a & b;

  task check(input string what, input string got, input string expected);
    if (got != expected) begin
      $display("FAIL %s: got %s expected %s", what, got, expected);
      $finish;
    end
  endtask

  initial begin
    #1;
    check("gate initial", $sformatf("%v", g), "WeX");
    check("variable initial", $sformatf("%v", w), "WeX");
    check("expression initial", $sformatf("%v", e), "WeX");
    check("asymmetric gate initial", $sformatf("%v", asym_g), "56X");
    check("asymmetric expression initial", $sformatf("%v", asym_e), "56X");
    check("highz initial", $sformatf("%v", highz_e), "WeH");
    check("variable delay initial", $sformatf("%v", variable_delay), "WeX");
    check("gate resolution", $sformatf("%v", resolved_g), "Pu0");
    check("expression resolution", $sformatf("%v", resolved_e), "Pu0");
    #3;
    check("gate zero", $sformatf("%v", g), "We0");
    check("expression zero", $sformatf("%v", e), "We0");
    check("highz zero", $sformatf("%v", highz_e), "HiZ");
    check("variable delay zero", $sformatf("%v", variable_delay), "We0");
    check("asymmetric zero", $sformatf("%v", asym_g), "Pu0");
    a = 1;
    #4;
    check("gate one", $sformatf("%v", g), "We1");
    check("expression one", $sformatf("%v", e), "We1");
    check("highz one", $sformatf("%v", highz_e), "We1");
    check("variable delay one", $sformatf("%v", variable_delay), "We1");
    check("asymmetric one", $sformatf("%v", asym_e), "St1");
    enable = 0;
    #4;
    check("tri-state off", $sformatf("%v", tri_g), "HiZ");
    enable = 1'bx;
    #4;
    check("tri-state ambiguous", $sformatf("%v", tri_g), "WeH");
    $display("PASSED");
  end
endmodule
