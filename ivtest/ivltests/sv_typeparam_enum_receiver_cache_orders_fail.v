// A symbolic inner specialization reached through an enclosing type formal may
// defer receiver-method lookup.  It must not share a specialization-cache entry
// with an explicitly concrete inner#(int).  Exercise both insertion orders.
module sv_typeparam_enum_receiver_cache_orders_fail;
  typedef enum int { SYNC_ACCEPTED, SYNC_UPDATED } sync_e;

  class valid_receiver;
    function sync_e nb_transport_fw(input int value);
      return value ? SYNC_UPDATED : SYNC_ACCEPTED;
    endfunction
  endclass

  class generic_first_inner #(type RECEIVER = int);
    RECEIVER m_receiver;

    function sync_e forward(input int value);
      return m_receiver.nb_transport_fw(value);
    endfunction
  endclass

  // This symbolic spelling reaches the cache before the explicit int spelling
  // below.  Only this use is eligible for template deferral.
  class generic_first_outer #(type IMP = int);
    generic_first_inner #(IMP) a_forwarded;
    generic_first_inner #(int) b_direct_bad;
  endclass

  class direct_first_inner #(type RECEIVER = int);
    RECEIVER m_receiver;

    function sync_e forward(input int value);
      return m_receiver.nb_transport_fw(value);
    endfunction
  endclass

  class direct_first_outer #(type IMP = int);
    // Populate the concrete specialization before the symbolic forwarding use.
    // The concrete error must not poison or be hidden by the later generic entry.
    direct_first_inner #(int) a_direct_bad;
    direct_first_inner #(IMP) b_forwarded;
  endclass

  generic_first_outer #(valid_receiver) generic_first_reachable;
  direct_first_outer #(valid_receiver) direct_first_reachable;
  valid_receiver receiver;
  sync_e observed;

  initial begin
    receiver = new;
    generic_first_reachable = new;
    direct_first_reachable = new;

    generic_first_reachable.a_forwarded = new;
    generic_first_reachable.a_forwarded.m_receiver = receiver;
    generic_first_reachable.b_direct_bad = new;

    direct_first_reachable.a_direct_bad = new;
    direct_first_reachable.b_forwarded = new;
    direct_first_reachable.b_forwarded.m_receiver = receiver;

    observed = generic_first_reachable.a_forwarded.forward(0);
    observed = generic_first_reachable.b_direct_bad.forward(0);
    observed = direct_first_reachable.a_direct_bad.forward(0);
    observed = direct_first_reachable.b_forwarded.forward(0);
  end
endmodule
