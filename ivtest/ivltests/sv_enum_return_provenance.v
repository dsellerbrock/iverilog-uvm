package enum_return_positive_pkg;
  typedef enum int {
    UVM_PHASE_SCHEDULE = 0,
    UVM_PHASE_NODE = 1
  } uvm_phase_type;

  function automatic uvm_phase_type free_phase_type();
    return UVM_PHASE_NODE;
  endfunction

  function automatic uvm_phase_type accept_phase_type(
      input uvm_phase_type value);
    return value;
  endfunction

  function automatic uvm_phase_type free_default(
      input uvm_phase_type value = free_phase_type());
    return value;
  endfunction

  class phase_base;
    virtual function uvm_phase_type get_phase_type();
      return UVM_PHASE_SCHEDULE;
    endfunction

    function uvm_phase_type method_default(
        input uvm_phase_type value = get_phase_type());
      return value;
    endfunction
  endclass

  class phase_node extends phase_base;
    extern virtual function uvm_phase_type get_phase_type();
  endclass

  function uvm_phase_type phase_node::get_phase_type();
    return UVM_PHASE_NODE;
  endfunction

  function automatic bit check(phase_base phase);
    uvm_phase_type assigned;
    uvm_phase_type initialized = phase.get_phase_type();
    assigned = phase.get_phase_type();
    return initialized == UVM_PHASE_NODE &&
           assigned == UVM_PHASE_NODE &&
           accept_phase_type(phase.get_phase_type()) == UVM_PHASE_NODE &&
           phase.method_default() == UVM_PHASE_NODE &&
           accept_phase_type(free_phase_type()) == UVM_PHASE_NODE &&
           free_default() == UVM_PHASE_NODE;
  endfunction
endpackage

module sv_enum_return_provenance;
  import enum_return_positive_pkg::*;
  initial begin
    phase_base phase;
    phase_node node;
    uvm_phase_type assigned;
    node = new;
    phase = node;
    assigned = phase.get_phase_type();
    if (!check(phase) || assigned != UVM_PHASE_NODE) begin
      $display("FAILED");
      $finish(1);
    end
    $display("PASSED");
  end
endmodule
