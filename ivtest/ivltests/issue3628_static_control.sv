class issue3628_control;
  static function int f(); return 2; endfunction
  function int g(); return 3; endfunction
endclass
module issue3628_static_control;
  issue3628_control obj;
  initial begin
    obj = new;
    if (issue3628_control::f() != 2 || obj.g() != 3)
      $fatal(1, "incorrect method result");
    $display("PASSED");
  end
endmodule
