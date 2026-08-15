// IEEE 1800-2017 20.14 and 40.3. Icarus does not instrument code
// coverage, so supported queries report the standard SV_COV_NOCOV status;
// unsupported state/database operations report their loud boundary.
module DUT;
endmodule

module test;
  DUT unit1();
  DUT unit2();

  int errors = 0;
  real functional_coverage;

  task automatic check(input string label, input int got, input int expected);
    if (got !== expected) begin
      errors += 1;
      $display("FAILED %s got=%0d expected=%0d", label, got, expected);
    end
  endtask

  initial begin
    check("SV_COV_START", `SV_COV_START, 0);
    check("SV_COV_STOP", `SV_COV_STOP, 1);
    check("SV_COV_RESET", `SV_COV_RESET, 2);
    check("SV_COV_CHECK", `SV_COV_CHECK, 3);
    check("SV_COV_MODULE", `SV_COV_MODULE, 10);
    check("SV_COV_HIER", `SV_COV_HIER, 11);
    check("SV_COV_ASSERTION", `SV_COV_ASSERTION, 20);
    check("SV_COV_FSM_STATE", `SV_COV_FSM_STATE, 21);
    check("SV_COV_STATEMENT", `SV_COV_STATEMENT, 22);
    check("SV_COV_TOGGLE", `SV_COV_TOGGLE, 23);
    check("SV_COV_OVERFLOW", `SV_COV_OVERFLOW, -2);
    check("SV_COV_ERROR", `SV_COV_ERROR, -1);
    check("SV_COV_NOCOV", `SV_COV_NOCOV, 0);
    check("SV_COV_OK", `SV_COV_OK, 1);
    check("SV_COV_PARTIAL", `SV_COV_PARTIAL, 2);

    check("check-root",
          $coverage_control(`SV_COV_CHECK, `SV_COV_TOGGLE,
                            `SV_COV_HIER, $root),
          `SV_COV_NOCOV);
    check("start-definition",
          $coverage_control(`SV_COV_START, `SV_COV_TOGGLE,
                            `SV_COV_HIER, "DUT"),
          `SV_COV_NOCOV);
    check("stop-instance",
          $coverage_control(`SV_COV_STOP, `SV_COV_TOGGLE,
                            `SV_COV_MODULE, unit1),
          `SV_COV_ERROR);
    check("reset-rooted-instance",
          $coverage_control(`SV_COV_RESET, `SV_COV_TOGGLE,
                            `SV_COV_MODULE, $root.test.unit2),
          `SV_COV_ERROR);
    check("get-max",
          $coverage_get_max(`SV_COV_TOGGLE, `SV_COV_HIER, "DUT"),
          `SV_COV_NOCOV);
    check("get",
          $coverage_get(`SV_COV_STATEMENT, `SV_COV_MODULE, unit1),
          `SV_COV_NOCOV);
    check("merge",
          $coverage_merge(`SV_COV_ASSERTION, "snapshot"),
          `SV_COV_ERROR);
    check("save",
          $coverage_save(`SV_COV_FSM_STATE, "snapshot"),
          `SV_COV_NOCOV);

    $set_coverage_db_name("functional.db");
    $load_coverage_db("functional.db");
    functional_coverage = $get_coverage();
    if (functional_coverage < 0.0 || functional_coverage > 100.0) begin
      errors += 1;
      $display("FAILED functional coverage range: %0f", functional_coverage);
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED: %0d checks", errors);
  end
endmodule
