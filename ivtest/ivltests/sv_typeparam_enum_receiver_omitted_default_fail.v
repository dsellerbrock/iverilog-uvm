// A bare class use applies its declared default at a concrete use site.  It is
// not the unspecialized template master and must not inherit template deferral.
module sv_typeparam_enum_receiver_omitted_default_fail;
  typedef enum int { SYNC_ACCEPTED, SYNC_UPDATED } sync_e;

  class wrapper #(type IMP = int);
    IMP m_imp;

    function sync_e forward(input int value);
      return m_imp.nb_transport_fw(value);
    endfunction
  endclass

  initial begin
    wrapper bad;
    sync_e result;

    bad = new;
    result = bad.forward(1);
  end
endmodule
