// A bare defaulted wrapper remains concrete when its property is inherited and
// used by a derived class method.
module sv_typeparam_enum_receiver_omitted_default_inherited_fail;
  typedef enum int { SYNC_ACCEPTED, SYNC_UPDATED } sync_e;

  class wrapper #(type IMP = int);
    IMP m_imp;

    function sync_e forward(input int value);
      return m_imp.nb_transport_fw(value);
    endfunction
  endclass

  class base_holder;
    wrapper bad;
  endclass

  class derived_holder extends base_holder;
    function sync_e invoke(input int value);
      bad = new;
      return bad.forward(value);
    endfunction
  endclass

  initial begin
    derived_holder h;
    sync_e result;

    h = new;
    result = h.invoke(1);
  end
endmodule
