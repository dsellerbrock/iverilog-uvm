module runtime_function_fixed_array_formal_test;
  logic [7:0] values [3];
  wire [7:0] maximum;

  function automatic logic [7:0] max_value(logic [7:0] input_values [3]);
    logic [7:0] current_max = '0;
    for (int i = 0; i < 3; i++) begin
      if (input_values[i] > current_max)
        current_max = input_values[i];
    end
    return current_max;
  endfunction

  assign maximum = max_value(values);

  initial begin
    values[0] = 8'h12;
    values[1] = 8'he1;
    values[2] = 8'h45;
    #1;
    if (maximum !== 8'he1)
      $fatal(1, "runtime fixed-array function input failed");
    values[1] = 8'h01;
    #1;
    if (maximum !== 8'h45)
      $fatal(1, "runtime fixed-array function input did not update");
    $display("PASS: runtime fixed-array function input");
  end
endmodule
