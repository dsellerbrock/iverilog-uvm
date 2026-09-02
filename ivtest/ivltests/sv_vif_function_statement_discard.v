// IEEE 1800-2017/2023 25.9 and 13.4.1: a nonvoid function result may be
// explicitly discarded with a void cast, but the selected function must still
// execute. Each return category needs its matching call and result-stack pop;
// treating every discarded function as a void function corrupts that stack.
class vif_function_discard_token;
  int origin;

  function new(input int value);
    origin = value;
  endfunction
endclass

interface vif_function_statement_discard_if;
  int calls = 0;
  int identity = 0;
  int object_calls = 0;
  int last_object_origin = -1;

  function automatic logic packed_result();
    calls += 1;
    return 1'b1;
  endfunction

  function automatic real real_result();
    calls += 1;
    return 1.5;
  endfunction

  function automatic string string_result();
    calls += 1;
    return "selected";
  endfunction

  function automatic vif_function_discard_token object_result();
    vif_function_discard_token result;
    result = new(identity);
    calls += 1;
    object_calls += 1;
    last_object_origin = result.origin;
    return result;
  endfunction
endinterface

module sv_vif_function_statement_discard;
  vif_function_statement_discard_if p0();
  vif_function_statement_discard_if p1();
  virtual vif_function_statement_discard_if vif;
  logic packed_value;
  real real_value;
  string string_value;
  vif_function_discard_token object_value;

  initial begin
    p0.identity = 11;
    p1.identity = 22;
    vif = p1;
    void'(vif.packed_result());
    void'(vif.real_result());
    void'(vif.string_result());
    void'(vif.object_result());

    // Consume the same return categories immediately afterward. A discarded
    // result left on the wrong typed stack can otherwise remain hidden below
    // the next call's value until thread cleanup.
    packed_value = vif.packed_result();
    real_value = vif.real_result();
    string_value = vif.string_result();
    object_value = vif.object_result();
    if (packed_value !== 1'b1 || real_value != 1.5 ||
        string_value != "selected" || object_value == null ||
        object_value.origin != 22)
      $fatal(1, "typed VIF result after discard was corrupted");

    if (p0.calls != 0 || p1.calls != 8)
      $fatal(1, "discarded VIF functions used the wrong instance");
    if (p0.object_calls != 0 || p1.object_calls != 2 ||
        p1.last_object_origin != 22)
      $fatal(1, "discarded object-return VIF function did not execute");
    $display("PASSED");
  end
endmodule
