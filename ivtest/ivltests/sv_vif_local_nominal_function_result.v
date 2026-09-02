// IEEE 1800-2017/2023 6.22.1 and 25.9: a declaration-view virtual
// interface and each matching physical interface instance elaborate local
// enum, unpacked-record, and class declarations as distinct netlist objects.
// Function dispatch must map those objects back to the same parsed nominal
// declaration without admitting an unrelated parameter specialization.
interface local_nominal_result_if #(
    parameter int WIDTH = 8
) (input int tag);
  typedef enum logic [(WIDTH/4)-1:0] {
    NOMINAL_IDLE = '0,
    NOMINAL_ACTIVE = 'd1
  } state_t;

  typedef struct {
    logic [WIDTH-1:0] payload;
    int origin;
  } record_t;

  class token_t;
    logic [WIDTH-1:0] payload;
    int origin;

    function new(input int value);
      payload = value;
      origin = value + 200;
    endfunction
  endclass

  int enum_calls = 0;
  int record_calls = 0;
  int class_calls = 0;

  function automatic state_t enum_value();
    enum_calls += 1;
    return NOMINAL_ACTIVE;
  endfunction

  function automatic record_t record_value();
    record_t result;
    result.payload = tag;
    result.origin = tag + 100;
    record_calls += 1;
    return result;
  endfunction

  function automatic token_t class_value();
    token_t result;
    result = new(tag);
    class_calls += 1;
    return result;
  endfunction
endinterface

module sv_vif_local_nominal_function_result;
  int unrelated_tag = 16;
  int first_tag = 3;
  int second_tag = 9;

  // Keep the incompatible specialization first. Its local declarations share
  // parsed source nodes with WIDTH=8 but have different evaluated layouts.
  local_nominal_result_if #(16) unrelated(unrelated_tag);
  local_nominal_result_if #(8) first(first_tag);
  local_nominal_result_if #(8) second(second_tag);
  virtual local_nominal_result_if #(8) vif;

  logic [1:0] enum_bits;
  int record_payload;
  int record_origin;
  int class_payload;
  int class_origin;

  task automatic check_selected(input int expected);
    enum_bits = vif.enum_value();
    record_payload = vif.record_value().payload;
    record_origin = vif.record_value().origin;
    class_payload = vif.class_value().payload;
    class_origin = vif.class_value().origin;
    if (enum_bits !== 1
        || record_payload != expected
        || record_origin != expected + 100
        || class_payload != expected
        || class_origin != expected + 200)
      $fatal(1, "interface-local nominal function result misdispatched");
  endtask

  initial begin
    vif = first;
    check_selected(3);
    vif = second;
    check_selected(9);

    if (unrelated.enum_calls != 0 || unrelated.record_calls != 0
        || unrelated.class_calls != 0
        || first.enum_calls != 1 || first.record_calls != 2
        || first.class_calls != 2
        || second.enum_calls != 1 || second.record_calls != 2
        || second.class_calls != 2)
      $fatal(1, "wrong nominal-result interface candidate executed");

    $display("PASSED");
  end
endmodule
