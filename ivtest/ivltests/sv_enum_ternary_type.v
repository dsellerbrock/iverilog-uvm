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

  // Function return: the shape used by prim_mubi_pkg / lc_ctrl_pkg.
  function automatic e_t bool_to_e(logic v);
    return (v ? A : B);
  endfunction

  e_t proc_val, cont_val, func_val;
  logic sel;

  // Continuous assignment.
  assign cont_val = sel ? A : B;

  int errors = 0;

  initial begin
    sel = 1'b1;
    #1;
    proc_val = sel ? A : B;   // procedural assignment
    func_val = bool_to_e(sel);
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

    sel = 1'b0;
    #1;
    proc_val = sel ? A : B;
    func_val = bool_to_e(sel);
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

    if (errors == 0) $display("PASSED");
    $finish(0);
  end

endmodule
