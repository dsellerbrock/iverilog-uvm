module sv_typeparam_enum_receiver_method_fail;
  typedef enum int { SYNC_ACCEPTED, SYNC_UPDATED } sync_e;
  typedef enum int { OTHER_ACCEPTED, OTHER_UPDATED } other_e;

  class integral_receiver;
    function int nb_transport_fw(input int value);
      return value;
    endfunction
  endclass

  class wrong_enum_receiver;
    function other_e nb_transport_fw(input int value);
      return OTHER_UPDATED;
    endfunction
  endclass

  class forwarding_wrapper #(type IMP = int);
    IMP m_imp;

    function new(IMP imp);
      m_imp = imp;
    endfunction

    function sync_e forward(input int value);
      return m_imp.nb_transport_fw(value);
    endfunction
  endclass

  initial begin
    integral_receiver integral_impl;
    wrong_enum_receiver enum_impl;
    forwarding_wrapper #(int) scalar_wrapper;
    forwarding_wrapper #(integral_receiver) integral_wrapper;
    forwarding_wrapper #(wrong_enum_receiver) enum_wrapper;
    sync_e result;

    integral_impl = new;
    enum_impl = new;
    scalar_wrapper = new(0);
    integral_wrapper = new(integral_impl);
    enum_wrapper = new(enum_impl);
    result = scalar_wrapper.forward(1);
    result = integral_wrapper.forward(1);
    result = enum_wrapper.forward(1);
  end
endmodule
