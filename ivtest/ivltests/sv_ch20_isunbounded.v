// IEEE 1800-2017 6.20.2.1 and 20.6: `$' is a symbolic unbounded
// parameter value, and $isunbounded distinguishes it from every ordinary
// constant or run-time expression.
module parameter_override #(
  parameter int P = 0
) (
  output logic result
);
  initial result = $isunbounded(P);
endmodule

module test;
  parameter int U = $;
  parameter int N = 42;
  parameter UNTYPED_U = $;
  parameter bit BIT_U = $;
  parameter logic [7:0] LOGIC_U = $;
  parameter integer INTEGER_U = $;
  parameter time TIME_U = $;
  localparam int ALIAS_U = U;
  localparam int ALIAS2_U = ALIAS_U;
  localparam int ALIAS_N = N;

  int errors = 0;
  int runtime_value = 17;
  logic override_result;
  logic ordered_override_result;

  parameter_override #(.P($)) overridden(override_result);
  parameter_override #($) ordered_overridden(ordered_override_result);

  task automatic check(input string label, input bit got, input bit expected);
    if (got !== expected) begin
      errors += 1;
      $display("FAILED %s got=%0b expected=%0b", label, got, expected);
    end
  endtask

  initial begin
    #1;
    check("bare", $isunbounded($), 1);
    check("int", $isunbounded(U), 1);
    check("untyped", $isunbounded(UNTYPED_U), 1);
    check("bit", $isunbounded(BIT_U), 1);
    check("logic-vector", $isunbounded(LOGIC_U), 1);
    check("integer", $isunbounded(INTEGER_U), 1);
    check("time", $isunbounded(TIME_U), 1);
    check("alias", $isunbounded(ALIAS_U), 1);
    check("alias-chain", $isunbounded(ALIAS2_U), 1);
    check("named-override", override_result, 1);
    check("ordered-override", ordered_override_result, 1);

    check("number", $isunbounded(1), 0);
    check("bounded-parameter", $isunbounded(N), 0);
    check("bounded-alias", $isunbounded(ALIAS_N), 0);
    check("constant-expression", $isunbounded(1 + 2), 0);
    check("run-time-expression", $isunbounded(runtime_value), 0);

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED: %0d checks", errors);
  end
endmodule
