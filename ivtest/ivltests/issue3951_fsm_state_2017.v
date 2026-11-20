`line 1 "issue3951_fsm_state.v" 0
module issue3951_machine #(
  parameter [2:0] /* tool enum E */ IDLE = 0, WAIT = 2, DONE = 3,
  parameter NESTED = 0, UNTAGGED = 7
);
  // tool state_vector st enum E
  parameter // tool enum E
    RUN = 1, IDLE_ALIAS = 8;
  logic [2:0] st = IDLE;
  logic [2:0] /* tool enum E */ next_state;
  /* tool state_vector ignored enum E extra_words */

  if (NESTED) begin : branch
    issue3951_machine #(.WAIT(5), .DONE(3'bxxx)) child();
  end
endmodule /* tool state_vector outside_module enum E */

module issue3951_unmarked;
  logic [2:0] st = 0;
endmodule

`define FSM `SV_COV_FSM_STATE
`define MOD `SV_COV_MODULE
`define HIER `SV_COV_HIER
`define GET(scope, target) $coverage_get(`FSM, scope, target)
`define MAX(scope, target) $coverage_get_max(`FSM, scope, target)
`define CTRL(op, scope, target) $coverage_control(op, `FSM, scope, target)

module issue3951_fsm_state;
  issue3951_machine #(.NESTED(1)) dut();
  issue3951_unmarked unmarked();

  task automatic check(input string what, input integer got, want);
    if (got !== want)
      $fatal(1, "%s got %0d, expected %0d", what, got, want);
  endtask

  initial begin
    check("available", `CTRL(`SV_COV_CHECK, `MOD, dut), `SV_COV_OK);
    check("deduplicated maximum", `MAX(`MOD, dut), 4);
    check("declaration initialization", `GET(`MOD, dut), 1);
    dut.st = 1;
    check("blocking update", `GET(`MOD, dut), 2);
    dut.st <= 2;
    check("before NBA", `GET(`MOD, dut), 2);
    #1;
    check("after NBA", `GET(`MOD, dut), 3);

    dut.st = 1;
    dut.st = 6;
    dut.st = 3'b00x;
    dut.st = 3'b0z1;
    dut.st = 2;
    check("repeated and undeclared states", `GET(`MOD, dut), 3);
    check("child initial hits", `GET(`MOD, dut.branch.child), 1);
    dut.branch.child.st = 2;
    check("child override excludes original value", `GET(`MOD, dut.branch.child), 1);
    dut.branch.child.st = 5;
    check("child override adds final value", `GET(`MOD, dut.branch.child), 2);

    check("unmarked sibling", `CTRL(`SV_COV_CHECK, `MOD, unmarked), `SV_COV_NOCOV);
    check("unmarked sibling maximum", `MAX(`MOD, unmarked), `SV_COV_NOCOV);
    check("instance hierarchy", `GET(`HIER, dut), 5);
    check("definition includes generated child and second root",
          `GET(`MOD, "issue3951_machine"), 6);
    check("definition hierarchy counts child once", `MAX(`HIER, "issue3951_machine"), 12);
    check("definition hierarchy fully available",
          `CTRL(`SV_COV_CHECK, `HIER, "issue3951_machine"), `SV_COV_OK);
    check("root hits", `GET(`HIER, $root), 6);
    check("root maximum", `MAX(`HIER, $root), 12);
    check("root MODULE excludes descendants", `MAX(`MOD, $root), `SV_COV_NOCOV);
    check("partially available root", `CTRL(`SV_COV_CHECK, `HIER, $root), `SV_COV_PARTIAL);

    check("stop", `CTRL(`SV_COV_STOP, `MOD, dut), `SV_COV_OK);
    dut.st = 3;
    check("stopped hits", `GET(`MOD, dut), 3);
    check("stopped maximum", `MAX(`MOD, dut), 4);
    check("stopped availability", `CTRL(`SV_COV_CHECK, `MOD, dut), `SV_COV_OK);
    check("reset", `CTRL(`SV_COV_RESET, `MOD, dut), `SV_COV_OK);
    dut.st = 0;
    dut.branch.child.st = 1;
    check("reset preserves stopped state", `GET(`MOD, dut), 0);
    check("reset preserves denominator", `MAX(`MOD, dut), 4);
    check("reset preserves availability", `CTRL(`SV_COV_CHECK, `MOD, dut), `SV_COV_OK);
    check("controls are instance-local", `GET(`MOD, dut.branch.child), 3);
    dut.branch.child.st = 'x;
    check("explicitly legal X state", `GET(`MOD, dut.branch.child), 4);

    check("restart", `CTRL(`SV_COV_START, `MOD, dut), `SV_COV_OK);
    check("restart does not record an update", `GET(`MOD, dut), 0);
    dut.st = 1;
    check("first update after restart", `GET(`MOD, dut), 1);
    check("repeated start", `CTRL(`SV_COV_START, `MOD, dut), `SV_COV_OK);
    dut.st = 2;
    check("second update after restart", `GET(`MOD, dut), 2);
    check("save with no backend", $coverage_save(`FSM, "issue3951_snapshot"), `SV_COV_ERROR);
    $display("PASSED");
  end
endmodule
