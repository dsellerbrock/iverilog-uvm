// A bare class-typed property is a concrete defaulted use, even while its
// enclosing holder class is being elaborated.
module sv_typeparam_enum_receiver_omitted_default_property_fail;
  typedef enum int { SYNC_ACCEPTED, SYNC_UPDATED } sync_e;

  class wrapper #(type IMP = int);
    IMP m_imp;

    function sync_e forward(input int value);
      return m_imp.nb_transport_fw(value);
    endfunction
  endclass

  class holder;
    wrapper bad;

    function sync_e invoke(input int value);
      bad = new;
      return bad.forward(value);
    endfunction
  endclass

  initial begin
    holder h;
    sync_e result;

    h = new;
    result = h.invoke(1);
  end
endmodule
