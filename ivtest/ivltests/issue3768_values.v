int unit_value = 41;
parameter int unit_step = 5;
typedef enum int { UNIT_ENUM = 13 } unit_t;
event ready;
event deferred;

package access_values;
  int from_initializer = unit_value + 1;
  int from_qualified_parameter = $unit::unit_step;
  int from_enum = UNIT_ENUM;

  function int read_unit();
    return unit_value;
  endfunction

  task write_and_trigger();
    unit_value = from_initializer + from_qualified_parameter + from_enum;
    -> ready;
    if (!$unit::ready.triggered())
      $fatal(1, "Package did not observe the triggered event");
    ->> deferred;
  endtask

  task wait_for_ready(output bit seen);
    @ready;
    seen = 1;
  endtask

  checker watch(input logic clk);
    observed: assert property (@(posedge clk) unit_value == 60)
      $display("CHECKER PASSED");
    else $fatal(1, "Checker lost the compilation-unit binding");
  endchecker
endpackage

module test;
  bit saw_ready, saw_deferred, clk;
  int unit_value = 123;
  access_values::watch watcher(clk);

  initial begin
    fork
      access_values::wait_for_ready(saw_ready);
      begin @deferred; saw_deferred = 1; end
    join_none
    #1;
    if (access_values::from_initializer !== 42 ||
        access_values::read_unit() !== 41 ||
        access_values::from_qualified_parameter !== 5 ||
        access_values::from_enum !== 13)
      $fatal(1, "Incorrect package reads");
    access_values::write_and_trigger();
    if (!$unit::ready.triggered())
      $fatal(1, "Module did not observe the triggered event");
    #1;
    if ($unit::unit_value !== 60 || !saw_ready || !saw_deferred)
      $fatal(1, "Incorrect package write or event binding");
    clk = 1;
    #1;
    $display("PASSED");
  end
endmodule
