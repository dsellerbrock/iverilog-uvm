// A force/release target is a temporary override, not a permanent
// procedural driver. It must remain legal when a continuous driver is
// elaborated later, for both resolved nets and SV variables.
module sv_force_continuous_driver_order;
  logic [3:0] source = 4'h3;
  wire  [3:0] net_value;
  logic [3:0] variable_value;
  int errors = 0;

  // Task bodies elaborate before module gates. This ordering ensures the
  // force l-values exist when the two continuous assignments are checked.
  task exercise_force;
    force net_value = 4'hF;
    force variable_value = 4'hE;
    #1;
    if (net_value !== 4'hF || variable_value !== 4'hE)
      errors++;
    release net_value;
    release variable_value;
    #1;
    if (net_value !== source || variable_value !== source)
      errors++;
    if (errors == 0)
      $display("PASSED");
    $finish;
  endtask

  initial exercise_force();

  assign net_value = source;
  assign variable_value = source;
endmodule
