// IEEE 1800-2017/2023 7.4, 7.9.11, and 10.9: a fixed unpacked prefix
// selects an independent associative-array value. Real-valued entry reads
// must retain that selected map receiver instead of addressing a nonexistent
// scalar signal for the complete fixed array.
module main;
  real values[1:2][string];
  bit failed;
  int outer;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  task automatic check_real(input string label,
                            input real actual,
                            input real expected);
    if (actual != expected) begin
      $display("FAILED -- %0s: got %0f, expected %0f",
               label, actual, expected);
      failed = 1'b1;
    end
  endtask

  initial begin
    failed = 1'b0;

    // Whole-map construction pins explicit and fallback state in slot 1.
    values[1] = '{"explicit":1.25, default:-1.50};
    check("constant outer explicit membership",
          values[1].size() == 1 && values[1].exists("explicit"));
    check_real("constant outer explicit read", values[1]["explicit"], 1.25);
    check("constant outer fallback is not a member",
          !values[1].exists("missing") && values[1].size() == 1);
    check_real("constant outer fallback read", values[1]["missing"], -1.50);

    // A direct entry store must lazily create only the selected sibling map.
    values[2]["direct"] = 2.50;
    check("direct store membership and sibling isolation",
          values[2].size() == 1 && values[2].exists("direct") &&
          !values[2].exists("explicit") &&
          values[1].size() == 1 && !values[1].exists("direct"));
    check_real("constant outer direct-entry read", values[2]["direct"], 2.50);

    // Variable outer selectors exercise the same canonical fixed-word path.
    outer = 1;
    check("variable outer slot 1 exists", values[outer].exists("explicit"));
    check_real("variable outer slot 1 explicit", values[outer]["explicit"], 1.25);
    check_real("variable outer slot 1 fallback", values[outer]["absent"], -1.50);

    outer = 2;
    values[outer]["variable"] = 3.75;
    check("variable outer direct store membership",
          values[outer].size() == 2 && values[outer].exists("direct") &&
          values[outer].exists("variable"));
    check_real("variable outer direct read", values[outer]["direct"], 2.50);
    check_real("variable outer stored read", values[outer]["variable"], 3.75);
    check_real("sibling remains unchanged", values[1]["explicit"], 1.25);

    if (failed)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule
