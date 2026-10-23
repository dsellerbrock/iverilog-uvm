module sv_virtual_method_override_signature_fail;
  class base;
    virtual function int f(int a); return a; endfunction
    virtual function int with_default(int a = 1); return a; endfunction
    virtual function int g(int a = 3); return a; endfunction
  endclass

  class renamed_arg extends base;
    function int f(int b); return b; endfunction
  endclass

  class changed_type extends base;
    function int f(byte a); return a; endfunction
  endclass

  class changed_direction extends base;
    function int f(output int a); a = 2; return a; endfunction
  endclass

  class changed_return extends base;
    function byte f(int a); return a; endfunction
  endclass

  class changed_default_presence extends base;
    function int with_default(int a); return a; endfunction
  endclass

  class changed_default_value extends base;
    function int g(int a = 7); return a; endfunction
  endclass
endmodule
