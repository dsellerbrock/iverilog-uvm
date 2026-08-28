// IEEE 1800-2017/2023 7.6 and 13.5.1: fixed unpacked-array subroutine
// arguments use assignment correspondence. The actual and formal therefore
// map left-to-left even when their ranges run in opposite directions.
module main;
  int failures;

  int task_in[10:1];
  int task_out[10:1];
  int task_io[10:1];

  int function_in[1:10];
  int function_out[1:10];
  int function_io[1:10];

  task automatic fixed_task(
      input int value_in[0:3],
      output int value_out[0:3],
      inout int value_io[0:3]);
    for (int ordinal = 0; ordinal < 4; ordinal++) begin
      if (value_in[ordinal] != 1008-ordinal) failures++;
      if (value_io[ordinal] != 2008-ordinal) failures++;
      value_out[ordinal] = 3000 + ordinal;
      value_io[ordinal] = 4000 + ordinal;
    end
  endtask

  function automatic void fixed_function(
      input int value_in[3:0],
      output int value_out[3:0],
      inout int value_io[3:0]);
    for (int ordinal = 0; ordinal < 4; ordinal++) begin
      if (value_in[3-ordinal] != 5003+ordinal) failures++;
      if (value_io[3-ordinal] != 6003+ordinal) failures++;
      value_out[3-ordinal] = 7000 + ordinal;
      value_io[3-ordinal] = 8000 + ordinal;
    end
  endfunction

  class Holder;
    int failures;
    int whole_in[8:5];
    int whole_out[8:5];
    int whole_io[8:5];
    int slice_in[10:1];
    int slice_out[10:1];
    int slice_io[10:1];

    task automatic fixed_property_task(
        input int value_in[0:3],
        output int value_out[0:3],
        inout int value_io[0:3],
        input int input_base,
        input int output_base,
        input int inout_input_base,
        input int inout_output_base);
      for (int ordinal = 0; ordinal < 4; ordinal++) begin
        if (value_in[ordinal] != input_base-ordinal) failures++;
        if (value_io[ordinal] != inout_input_base-ordinal) failures++;
        value_out[ordinal] = output_base + ordinal;
        value_io[ordinal] = inout_output_base + ordinal;
      end
    endtask

    task run();
      foreach (whole_in[i]) whole_in[i] = 100 + i;
      foreach (whole_out[i]) whole_out[i] = -1;
      foreach (whole_io[i]) whole_io[i] = 200 + i;

      fixed_property_task(whole_in, whole_out, whole_io,
                          108, 9000, 208, 10000);
      for (int ordinal = 0; ordinal < 4; ordinal++) begin
        if (whole_out[8-ordinal] != 9000+ordinal) failures++;
        if (whole_io[8-ordinal] != 10000+ordinal) failures++;
      end

      foreach (slice_in[i]) slice_in[i] = 300 + i;
      foreach (slice_out[i]) slice_out[i] = -1;
      foreach (slice_io[i]) slice_io[i] = 400 + i;

      fixed_property_task(slice_in[8:5], slice_out[8:5], slice_io[8:5],
                          308, 11000, 408, 12000);
      for (int ordinal = 0; ordinal < 4; ordinal++) begin
        if (slice_out[8-ordinal] != 11000+ordinal) failures++;
        if (slice_io[8-ordinal] != 12000+ordinal) failures++;
      end
      if (slice_out[9] != -1 || slice_out[4] != -1) failures++;
      if (slice_io[9] != 409 || slice_io[4] != 404) failures++;
    endtask
  endclass

  Holder holder;

  initial begin
    foreach (task_in[i]) task_in[i] = 1000 + i;
    foreach (task_out[i]) task_out[i] = -1;
    foreach (task_io[i]) task_io[i] = 2000 + i;
    fixed_task(task_in[8:5], task_out[8:5], task_io[8:5]);
    for (int ordinal = 0; ordinal < 4; ordinal++) begin
      if (task_out[8-ordinal] != 3000+ordinal) failures++;
      if (task_io[8-ordinal] != 4000+ordinal) failures++;
    end
    if (task_out[9] != -1 || task_out[4] != -1) failures++;
    if (task_io[9] != 2009 || task_io[4] != 2004) failures++;

    foreach (function_in[i]) function_in[i] = 5000 + i;
    foreach (function_out[i]) function_out[i] = -1;
    foreach (function_io[i]) function_io[i] = 6000 + i;
    fixed_function(function_in[3:6], function_out[3:6], function_io[3:6]);
    for (int ordinal = 0; ordinal < 4; ordinal++) begin
      if (function_out[3+ordinal] != 7000+ordinal) failures++;
      if (function_io[3+ordinal] != 8000+ordinal) failures++;
    end
    if (function_out[2] != -1 || function_out[7] != -1) failures++;
    if (function_io[2] != 6002 || function_io[7] != 6007) failures++;

    holder = new;
    holder.run();
    failures += holder.failures;

    if (failures != 0) $fatal(1, "fixed slice/property direction failures=%0d",
                              failures);
    $display("PASSED");
    $finish(0);
  end
endmodule
