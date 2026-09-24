interface nb_driver_if;
  logic [7:0] value;
  task drive(input logic [7:0] next_value);
    value <= next_value;
  endtask
  task drive_delayed(input logic [7:0] next_value);
    value <= #2 next_value;
  endtask
endinterface

module sv_interface_task_mixed_driver_nb;
  logic [7:0] source;
  nb_driver_if idle();
  assign idle.value = source;
`ifdef CALLED
  initial idle.drive(8'hff);
`endif
  initial begin
    source = 8'h12;
    #1;
    if (idle.value !== 8'h12) $fatal(1, "unused NBA disturbed continuous driver");
    source = 8'h34;
    #1;
    if (idle.value !== 8'h34) $fatal(1, "unused delayed NBA disturbed continuous driver");
    $display("PASSED");
    $finish(0);
  end
endmodule
