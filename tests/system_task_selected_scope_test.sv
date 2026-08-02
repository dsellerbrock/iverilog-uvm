// IEEE 1800-2017 20.12: assertion-control system tasks accept a hierarchical
// scope argument. A selected instance-array scope must remain a VPI scope
// handle rather than being padded/evaluated as a vector expression.
interface check_if;
  logic value;
endinterface

module system_task_selected_scope_test;
  check_if checks[2]();

  initial begin
    $asserton(0, checks[0]);
    $assertkill(0, checks[0]);
    $assertoff(0, checks[0]);
    $display("SYSTEM TASK SELECTED SCOPE TEST: PASS");
  end
endmodule
