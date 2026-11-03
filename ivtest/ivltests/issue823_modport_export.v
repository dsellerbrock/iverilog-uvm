interface issue823_generic_if;
  logic [7:0] data;
  modport provider (ref data, export Read);
  modport consumer (ref data,
                    import task Read(input logic [7:0] address));
endinterface

interface issue823_typed_if;
  logic [7:0] data;
  modport provider (output data, export Read);
  modport consumer (input data,
                    import task Read(input logic [7:0] address));
endinterface

module issue823_generic_memory(interface a);
  task a.Read(input logic [7:0] address);
    a.data = address + 1;
    $display("EREAD %0d", address);
  endtask
endmodule

module issue823_generic_cpu(issue823_generic_if.consumer b);
  task run;
    b.Read(8'd4);
    $display("EDATA %0d", b.data);
    if (b.data !== 8'd5) $fatal(1, "bad generic export result");
  endtask
endmodule

module issue823_typed_memory(issue823_typed_if.provider a);
  task automatic a.Read(input logic [7:0] address);
    a.data = address + 1;
    $display("TREAD %0d", address);
  endtask
endmodule

module issue823_typed_cpu(issue823_typed_if.consumer b);
  task run;
    b.Read(8'd4);
    $display("TDATA %0d", b.data);
    if (b.data !== 8'd5) $fatal(1, "bad typed export result");
  endtask
endmodule

module issue823_modport_export;
  issue823_generic_if generic_bus();
  issue823_generic_memory generic_memory(generic_bus);
  issue823_generic_cpu generic_cpu(generic_bus);

  issue823_typed_if typed_bus();
  issue823_typed_memory typed_memory(typed_bus);
  issue823_typed_cpu typed_cpu(typed_bus);

  initial begin
    #1;
    generic_cpu.run();
    typed_cpu.run();
    $display("PASSED");
  end
endmodule
