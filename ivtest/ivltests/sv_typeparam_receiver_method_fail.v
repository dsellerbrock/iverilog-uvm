// The template-only deferral must not hide an ordinary unresolved method.
module sv_typeparam_receiver_method_fail;

  class receiver_impl;
  endclass

  class ordinary_proxy;
    receiver_impl m_imp;

    function bit forward();
      return m_imp.no_such_method();
    endfunction
  endclass

endmodule
