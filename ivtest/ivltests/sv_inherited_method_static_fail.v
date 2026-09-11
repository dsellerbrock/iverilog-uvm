// IEEE 1800-2017/2023 8.10.
package p;
  function int enabled(); return 7; endfunction
  class base;
    int value=42;
    function int enabled(); return value; endfunction
  endclass
  class child extends base;
    static function int check(); return enabled(); endfunction
  endclass
endpackage
module sv_inherited_method_static_fail;
  import p::*;
  initial $display("%0d",child::check());
endmodule
