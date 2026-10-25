module top;
  task wait_20(); fork #20; return; join_none endtask
  initial wait_20();
endmodule
