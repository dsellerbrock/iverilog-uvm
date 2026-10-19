// IEEE 1800-2017 A.9.3 note 37 and 13.5.5, and 1800-2023 13.5.5:
// empty parentheses may be omitted for a nonrecursive class function method.
class child_config;
  function string convert2string();
    return "child";
  endfunction
endclass

class env_config;
  child_config child;

  function string implicit_call();
    return {"prefix:", child.convert2string};
  endfunction

  function string explicit_control();
    return {"prefix:", child.convert2string()};
  endfunction
endclass

module test;
  env_config cfg;

  initial begin
    cfg = new();
    cfg.child = new();
    if (cfg.implicit_call() != "prefix:child")
      $fatal(1, "parentheses-free class method in string concat failed");
    if (cfg.explicit_control() != "prefix:child")
      $fatal(1, "parenthesized class method control failed");
    $display("PASSED");
  end
endmodule
