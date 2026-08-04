// IEEE 1800-2017 11.4.11: when both arms of the conditional operator have
// the same type, the result has that type. Two operands of the same
// enumeration type therefore yield that enumeration type, so
// `e = cond ? A : B;' is a legal 6.19.3 assignment with no cast -- even
// when the condition is a 4-state `logic'.
//
// This is the idiom OpenTitan uses for every multi-bit-encoded control
// signal (`mubi4_bool_to_mubi', `lc_tx_bool_to_lc_tx', and the state
// updates in prim_alert_sender / tlul_adapter_reg).

module sv_enum_ternary_type;

  typedef enum logic [3:0] { A = 4'h6, B = 4'h9 } e_t;
  typedef enum {
    D_IDLE, D_START, D_RESTART, D_ADDR, D_READ, D_WRITE,
    D_READ_ACK, D_READ_NACK, D_WRITE_ACK, D_WRITE_NACK,
    D_READ_DATA, D_WRITE_DATA, D_READ_DATA_ACK, D_READ_DATA_NACK,
    D_WRITE_DATA_ACK, D_WRITE_DATA_NACK, D_STOP
  } default_e_t;

  // Function return: the shape used by prim_mubi_pkg / lc_ctrl_pkg.
  function automatic e_t bool_to_e(logic v);
    return (v ? A : B);
  endfunction

  function automatic default_e_t bool_to_default_e(logic v);
    return (v ? D_START : D_RESTART);
  endfunction

  e_t proc_val, cont_val, func_val;
  default_e_t default_proc_val, default_cont_val, default_func_val;
  logic sel;

  // Continuous assignment.
  assign cont_val = sel ? A : B;
  assign default_cont_val = sel ? D_START : D_RESTART;

  int errors = 0;

  initial begin
    sel = 1'b1;
    #1;
    proc_val = sel ? A : B;   // procedural assignment
    func_val = bool_to_e(sel);
    default_proc_val = sel ? D_START : D_RESTART;
    default_func_val = bool_to_default_e(sel);
    if (proc_val !== A) begin
      $display("FAILED -- procedural ternary gave %h, want %h", proc_val, A);
      errors++;
    end
    if (cont_val !== A) begin
      $display("FAILED -- continuous ternary gave %h, want %h", cont_val, A);
      errors++;
    end
    if (func_val !== A) begin
      $display("FAILED -- function ternary gave %h, want %h", func_val, A);
      errors++;
    end
    if (default_proc_val !== D_START || default_cont_val !== D_START ||
        default_func_val !== D_START) begin
      $display("FAILED -- default-base enum true arm lost its type/value");
      errors++;
    end

    sel = 1'b0;
    #1;
    proc_val = sel ? A : B;
    func_val = bool_to_e(sel);
    default_proc_val = sel ? D_START : D_RESTART;
    default_func_val = bool_to_default_e(sel);
    if (proc_val !== B) begin
      $display("FAILED -- procedural ternary gave %h, want %h", proc_val, B);
      errors++;
    end
    if (cont_val !== B) begin
      $display("FAILED -- continuous ternary gave %h, want %h", cont_val, B);
      errors++;
    end
    if (func_val !== B) begin
      $display("FAILED -- function ternary gave %h, want %h", func_val, B);
      errors++;
    end
    if (default_proc_val !== D_RESTART || default_cont_val !== D_RESTART ||
        default_func_val !== D_RESTART) begin
      $display("FAILED -- default-base enum false arm lost its type/value");
      errors++;
    end

    if (errors == 0) $display("PASSED");
    $finish(0);
  end

endmodule
