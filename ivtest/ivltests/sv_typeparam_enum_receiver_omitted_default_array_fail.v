// A fixed array of bare class uses applies the concrete default to every
// element.  Array wrapping must not make that receiver look symbolic.
module sv_typeparam_enum_receiver_omitted_default_array_fail;
  typedef enum int { SYNC_ACCEPTED, SYNC_UPDATED } sync_e;

  class wrapper #(type IMP = int);
    IMP m_imp;

    function sync_e forward(input int value);
      return m_imp.nb_transport_fw(value);
    endfunction
  endclass

  wrapper bad[1];

  initial begin
    sync_e result;

    bad[0] = new;
    result = bad[0].forward(1);
  end
endmodule
