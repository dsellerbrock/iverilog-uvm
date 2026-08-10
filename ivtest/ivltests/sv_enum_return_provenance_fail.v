package enum_return_negative_pkg;
  typedef enum int { A_IDLE, A_RUN } enum_a_t;
  typedef enum int { B_IDLE, B_RUN } enum_b_t;

  function automatic enum_b_t free_b();
    return B_RUN;
  endfunction

  function automatic enum_a_t accept_a(input enum_a_t value);
    return value;
  endfunction

  function automatic enum_a_t bad_free_default(
      input enum_a_t value = free_b());
    return value;
  endfunction

  class phase_like;
    extern function enum_b_t get_phase_type();

    function enum_a_t bad_method_default(
        input enum_a_t value = get_phase_type());
      return value;
    endfunction
  endclass

  function enum_b_t phase_like::get_phase_type();
    return B_RUN;
  endfunction

  function automatic void invalid_uses(phase_like phase);
    enum_a_t assigned;
    enum_a_t initialized = phase.get_phase_type();
    assigned = phase.get_phase_type();
    assigned = accept_a(phase.get_phase_type());
  endfunction
endpackage

module sv_enum_return_provenance_fail;
  import enum_return_negative_pkg::*;
  initial begin
    phase_like phase;
    phase = new;
    invalid_uses(phase);
    $display("FAILED");
  end
endmodule
