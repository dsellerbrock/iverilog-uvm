interface issue824_if;
  int slaves = 0;
  extern forkjoin task countSlaves();
  modport slave (ref slaves, export countSlaves);

  initial begin
    #1;
    countSlaves();
    if (slaves !== 2)
      $fatal(1, "extern forkjoin called %0d providers, expected 2", slaves);
    $display("SLAVES %0d", slaves);
    $display("PASSED");
    $finish;
  end
endinterface

module issue824_mem(issue824_if.slave bus);
  task bus.countSlaves();
    bus.slaves++;
  endtask
endmodule

module issue824_extern_forkjoin;
  issue824_if bus();
  issue824_mem m0(bus.slave);
  issue824_mem m1(bus.slave);
endmodule
