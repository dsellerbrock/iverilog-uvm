// IEEE 1800-2017 6.19.4, 11.6, 11.8 and 13.5.3: an input
// default is an assignment-like context. Enum members used in a numerical
// expression take their base integral type, and the formal's width participates
// in sizing that expression. This is the shape used by UVM's report catcher.
module sv_enum_default_formal_width;
  typedef int uvm_action;
  typedef enum {
    UVM_NO_ACTION = 'b0000000,
    UVM_LOG       = 'b0000010,
    UVM_RM_RECORD = 'b1000000,
    UVM_EXTRA     = 'h100
  } uvm_action_type;

  typedef enum logic [6:0] {
    U7_LO = 7'h02,
    U7_HI = 7'h40
  } unsigned7_t;

  typedef enum logic signed [6:0] {
    S7_NEG_TWO = -7'sd2,
    S7_ONE     =  7'sd1
  } signed7_t;

  typedef enum logic [3:0] {
    X_LEFT  = 4'b1x00,
    Z_RIGHT = 4'b00z1
  } four_state_t;

  typedef enum int { E_A = 1, E_B = 2, E_AB = 3 } enum_t;

  int helper_calls;

  function automatic uvm_action next_action();
    helper_calls++;
    return UVM_LOG | UVM_RM_RECORD;
  endfunction

  function automatic uvm_action action_default(
      input uvm_action action = (UVM_LOG | UVM_RM_RECORD));
    return action;
  endfunction

  function automatic uvm_action nested_parens_default(
      input uvm_action action = (((UVM_LOG) | (UVM_RM_RECORD))));
    return action;
  endfunction

  function automatic longint unsigned widened_default(
      input longint unsigned action = (U7_LO | U7_HI));
    return action;
  endfunction

  function automatic byte narrowed_default(
      input byte action = (UVM_LOG | UVM_RM_RECORD | UVM_EXTRA));
    return action;
  endfunction

  function automatic logic signed [15:0] signed_default(
      input logic signed [15:0] action = (S7_NEG_TWO | S7_ONE));
    return action;
  endfunction

  function automatic int four_state_default(
      input int action = (X_LEFT | Z_RIGHT));
    return action;
  endfunction

  function automatic enum_t enum_member_default(input enum_t value = E_A);
    return value;
  endfunction

  function automatic enum_t enum_cast_default(
      input enum_t value = enum_t'(E_A | E_B));
    return value;
  endfunction

  function automatic uvm_action helper_default(
      input uvm_action action = next_action());
    return action;
  endfunction

  task automatic action_task(output uvm_action result,
      input uvm_action action = (UVM_LOG | UVM_RM_RECORD));
    result = action;
  endtask

  class Holder;
    uvm_action action;

    function new(input uvm_action value = (UVM_LOG | UVM_RM_RECORD));
      action = value;
    endfunction

    function automatic uvm_action method_default(
        input uvm_action value = (UVM_LOG | UVM_RM_RECORD));
      return value;
    endfunction
  endclass

  uvm_action task_result;
  Holder holder;

  initial begin
    if (action_default() !== 32'h42 || action_default(7) !== 7)
      $fatal(1, "FAILED -- UVM-shaped int default");
    if (nested_parens_default() !== 32'h42)
      $fatal(1, "FAILED -- parentheses changed default expression");
    if (widened_default() !== 64'h42)
      $fatal(1, "FAILED -- unsigned widening");
    if (narrowed_default() !== 8'h42)
      $fatal(1, "FAILED -- legal narrowing");
    if (signed_default() !== 16'hffff)
      $fatal(1, "FAILED -- signed widening");
    if (four_state_default() !== 32'h9)
      $fatal(1, "FAILED -- four-state to two-state conversion");
    if (enum_member_default() !== E_A || enum_cast_default() !== E_AB)
      $fatal(1, "FAILED -- legal enum defaults");

    helper_calls = 0;
    if (helper_default() !== 32'h42 || helper_calls != 1)
      $fatal(1, "FAILED -- first omitted argument evaluation");
    if (helper_default(9) !== 9 || helper_calls != 1)
      $fatal(1, "FAILED -- explicit argument evaluated its default");
    if (helper_default() !== 32'h42 || helper_calls != 2)
      $fatal(1, "FAILED -- repeated omitted argument evaluation");

    action_task(task_result);
    if (task_result !== 32'h42)
      $fatal(1, "FAILED -- task default");

    holder = new;
    if (holder.action !== 32'h42 || holder.method_default() !== 32'h42)
      $fatal(1, "FAILED -- class defaults");

    $display("PASSED");
  end
endmodule
