package sv_typeparam_enum_receiver_pkg_alias_collision_pkg;
  // The terminal alias deliberately has the same name as the unrelated class
  // formal below.  Its package identity must survive every alias hop.
  typedef int IMP;
  typedef IMP hop1_t;
  typedef hop1_t hop2_t;
endpackage

module sv_typeparam_enum_receiver_pkg_alias_collision_fail;
  typedef enum int { SYNC_ACCEPTED, SYNC_UPDATED } sync_e;

  class alias_inner #(type RECEIVER = int);
    RECEIVER m_receiver;

    function sync_e forward(input int value);
      return m_receiver.nb_transport_fw(value);
    endfunction
  endclass

  class valid_receiver;
    function sync_e nb_transport_fw(input int value);
      return value ? SYNC_UPDATED : SYNC_ACCEPTED;
    endfunction
  endclass

  class alias_outer #(type IMP = int);
    // p::hop2_t is concretely int.  Resolving it through p::IMP must not make
    // this inner actual look dependent on alias_outer's distinct IMP formal.
    alias_inner #(
      sv_typeparam_enum_receiver_pkg_alias_collision_pkg::hop2_t
    ) m_inner;
  endclass

  alias_outer #(valid_receiver) collision_bad;
  sync_e observed;

  initial begin
    collision_bad = new;
    collision_bad.m_inner = new;
    observed = collision_bad.m_inner.forward(1);
  end
endmodule
