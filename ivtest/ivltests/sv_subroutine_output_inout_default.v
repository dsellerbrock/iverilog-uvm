module defaults;
  int output_target;
  int inout_target;

  task automatic set_task(input int value, output int result = output_target);
    result = value;
  endtask

  task automatic add_task(input int delta, inout int value = inout_target);
    value += delta;
  endtask

  function automatic int set_function(input int value,
                                      output int result = output_target);
    result = value;
    return value;
  endfunction

  function automatic int add_function(input int delta,
                                      inout int value = inout_target);
    value += delta;
    return value;
  endfunction
endmodule

class class_defaults;
  int target;

  task set(input int value, output int result = target);
    result = value;
  endtask
endclass

module main;
  defaults d();
  class_defaults c;
  int output_target;
  int explicit_value;
  int result;

  initial begin
    d.output_target = 0;
    d.inout_target = 10;
    output_target = 99;

    d.set_task(1,);
    if (d.output_target != 1 || output_target != 99)
      $fatal(1, "task output default used caller scope");
    d.set_task(.value(2), .result());
    if (d.output_target != 2)
      $fatal(1, "named task output default failed");
    d.set_task(3, explicit_value);
    if (explicit_value != 3 || d.output_target != 2)
      $fatal(1, "explicit task output did not override default");

    d.add_task(5,);
    if (d.inout_target != 15)
      $fatal(1, "task inout default copy-in/copy-out failed");
    d.add_task(.delta(2), .value());
    if (d.inout_target != 17)
      $fatal(1, "named task inout default failed");

    c = new;
    c.target = 0;
    c.set(6,);
    if (c.target != 6)
      $fatal(1, "class task output default failed");

    result = d.set_function(4,);
    if (result != 4 || d.output_target != 4 || output_target != 99)
      $fatal(1, "function output default failed");
    result = d.add_function(3,);
    if (result != 20 || d.inout_target != 20)
      $fatal(1, "function inout default copy-in/copy-out failed");

    $display("PASS");
  end
endmodule
