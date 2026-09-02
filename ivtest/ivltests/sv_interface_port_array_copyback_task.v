interface port_array_copyback_if;
  int value;
  int calls;

  task automatic update(output int selected,
                        inout int accumulated,
                        ref int referenced);
    selected = value;
    accumulated += value;
    referenced += value * 100;
    calls += 1;
  endtask

  modport access(input value, import update);
endinterface

module port_array_copyback_consumer(
  port_array_copyback_if.access ports [0:1]
);
  int selected;
  int accumulated;
  int referenced;

  initial begin
    #1;
    selected = -1;
    accumulated = 10;
    referenced = 1;
    ports[1].update(selected, accumulated, referenced);
    if (selected != 7 || accumulated != 17 || referenced != 701)
      $fatal(1, "interface-port array task copyback used the wrong word");
    $display("PASSED");
  end
endmodule

module sv_interface_port_array_copyback_task;
  port_array_copyback_if bus [0:1] ();
  port_array_copyback_consumer consumer(.ports(bus));

  initial begin
    bus[0].value = 2;
    bus[1].value = 7;
  end
endmodule
