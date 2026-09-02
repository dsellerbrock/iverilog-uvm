// A static subroutine may have more object-valued actuals than the VVP
// evaluator's historical fixed stack depth. Argument preservation must grow
// on demand without changing class-handle or fixed-array value semantics.
class vif_static_stack_token;
  int value;
  function new(input int initial_value);
    value = initial_value;
  endfunction
endclass

interface vif_static_object_stack_if;
  int result;

  // Keep a virtual-interface task on the historical static-subroutine
  // evaluate-all/then-store path. Forty object-valued actuals prove that the
  // VVP object stack grows beyond its former 32-entry ceiling even though
  // value-returning virtual-interface functions now marshal sequentially.
  task static class_task(
      input vif_static_stack_token c0,
      input vif_static_stack_token c1,
      input vif_static_stack_token c2,
      input vif_static_stack_token c3,
      input vif_static_stack_token c4,
      input vif_static_stack_token c5,
      input vif_static_stack_token c6,
      input vif_static_stack_token c7,
      input vif_static_stack_token c8,
      input vif_static_stack_token c9,
      input vif_static_stack_token c10,
      input vif_static_stack_token c11,
      input vif_static_stack_token c12,
      input vif_static_stack_token c13,
      input vif_static_stack_token c14,
      input vif_static_stack_token c15,
      input vif_static_stack_token c16,
      input vif_static_stack_token c17,
      input vif_static_stack_token c18,
      input vif_static_stack_token c19,
      input vif_static_stack_token c20,
      input vif_static_stack_token c21,
      input vif_static_stack_token c22,
      input vif_static_stack_token c23,
      input vif_static_stack_token c24,
      input vif_static_stack_token c25,
      input vif_static_stack_token c26,
      input vif_static_stack_token c27,
      input vif_static_stack_token c28,
      input vif_static_stack_token c29,
      input vif_static_stack_token c30,
      input vif_static_stack_token c31,
      input vif_static_stack_token c32,
      input vif_static_stack_token c33,
      input vif_static_stack_token c34,
      input vif_static_stack_token c35,
      input vif_static_stack_token c36,
      input vif_static_stack_token c37,
      input vif_static_stack_token c38,
      input vif_static_stack_token c39);
    result = c0.value + c39.value;
  endtask
endinterface

module sv_vif_function_static_object_stack_growth;
  vif_static_stack_token token;
  int values [0:0];
  int result;
  vif_static_object_stack_if concrete();
  virtual vif_static_object_stack_if vif;

  function int class_sum(
      input vif_static_stack_token c0,
      input vif_static_stack_token c1,
      input vif_static_stack_token c2,
      input vif_static_stack_token c3,
      input vif_static_stack_token c4,
      input vif_static_stack_token c5,
      input vif_static_stack_token c6,
      input vif_static_stack_token c7,
      input vif_static_stack_token c8,
      input vif_static_stack_token c9,
      input vif_static_stack_token c10,
      input vif_static_stack_token c11,
      input vif_static_stack_token c12,
      input vif_static_stack_token c13,
      input vif_static_stack_token c14,
      input vif_static_stack_token c15,
      input vif_static_stack_token c16,
      input vif_static_stack_token c17,
      input vif_static_stack_token c18,
      input vif_static_stack_token c19,
      input vif_static_stack_token c20,
      input vif_static_stack_token c21,
      input vif_static_stack_token c22,
      input vif_static_stack_token c23,
      input vif_static_stack_token c24,
      input vif_static_stack_token c25,
      input vif_static_stack_token c26,
      input vif_static_stack_token c27,
      input vif_static_stack_token c28,
      input vif_static_stack_token c29,
      input vif_static_stack_token c30,
      input vif_static_stack_token c31,
      input vif_static_stack_token c32,
      input vif_static_stack_token c33,
      input vif_static_stack_token c34,
      input vif_static_stack_token c35,
      input vif_static_stack_token c36,
      input vif_static_stack_token c37,
      input vif_static_stack_token c38,
      input vif_static_stack_token c39);
    return c0.value + c39.value;
  endfunction

  function int fixed_array_sum(
      input int a0 [0:0],
      input int a1 [0:0],
      input int a2 [0:0],
      input int a3 [0:0],
      input int a4 [0:0],
      input int a5 [0:0],
      input int a6 [0:0],
      input int a7 [0:0],
      input int a8 [0:0],
      input int a9 [0:0],
      input int a10 [0:0],
      input int a11 [0:0],
      input int a12 [0:0],
      input int a13 [0:0],
      input int a14 [0:0],
      input int a15 [0:0],
      input int a16 [0:0],
      input int a17 [0:0],
      input int a18 [0:0],
      input int a19 [0:0],
      input int a20 [0:0],
      input int a21 [0:0],
      input int a22 [0:0],
      input int a23 [0:0],
      input int a24 [0:0],
      input int a25 [0:0],
      input int a26 [0:0],
      input int a27 [0:0],
      input int a28 [0:0],
      input int a29 [0:0],
      input int a30 [0:0],
      input int a31 [0:0]);
    return a0[0] + a31[0];
  endfunction

  initial begin
    token = new(5);
    values[0] = 6;
    vif = concrete;
    vif.class_task(token, token, token, token, token, token, token, token,
                   token, token, token, token, token, token, token, token,
                   token, token, token, token, token, token, token, token,
                   token, token, token, token, token, token, token, token,
                   token, token, token, token, token, token, token, token);
    if (concrete.result != 10)
      $fatal(1, "40-class-argument static VIF task returned %0d",
             concrete.result);
    result = class_sum(token, token, token, token, token, token, token, token,
                       token, token, token, token, token, token, token, token,
                       token, token, token, token, token, token, token, token,
                       token, token, token, token, token, token, token, token,
                       token, token, token, token, token, token, token, token);
    if (result != 10)
      $fatal(1, "40-class-argument static function returned %0d", result);
    result = fixed_array_sum(values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values, values);
    if (result != 12)
      $fatal(1, "32-array-argument static function returned %0d", result);
    $display("PASSED");
  end
endmodule
