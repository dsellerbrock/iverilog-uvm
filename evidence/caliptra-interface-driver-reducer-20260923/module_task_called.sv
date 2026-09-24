module task_top(input logic source);
  logic driven;
  assign driven = source;
  task drive(); driven = 1'b0; endtask
  initial drive();
endmodule
