package pkg_class_static_call_nonstatic_pkg;
  class call_target;
    function void m();
    endfunction
  endclass
endpackage

module sv_pkg_class_static_call_nonstatic_fail;
  initial pkg_class_static_call_nonstatic_pkg::call_target::m();
endmodule
