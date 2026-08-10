// A source-level IMP reference is not necessarily symbolic: after outer#(int)
// is selected, inner#(IMP) is the concrete and invalid inner#(int).
module sv_typeparam_enum_receiver_concrete_outer_fail;
  typedef enum int { SYNC_ACCEPTED, SYNC_UPDATED } sync_e;

  class inner #(type RECEIVER = int);
    RECEIVER m_receiver;

    function new(RECEIVER receiver);
      m_receiver = receiver;
    endfunction

    function sync_e forward(input int value);
      return m_receiver.nb_transport_fw(value);
    endfunction
  endclass

  class outer #(type IMP = int);
    inner #(IMP) m_inner;

    function new(IMP receiver);
      m_inner = new(receiver);
    endfunction

    function sync_e forward(input int value);
      return m_inner.forward(value);
    endfunction
  endclass

  initial begin
    outer #(int) concrete_bad;
    sync_e result;

    concrete_bad = new(0);
    result = concrete_bad.forward(1);
  end
endmodule
