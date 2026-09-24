module task_top(input logic source);
  logic driven;
  assign driven = source;
  task unused(); driven = 1'b0; endtask
endmodule
