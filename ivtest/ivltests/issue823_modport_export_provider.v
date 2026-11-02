interface sb2;
  logic [7:0] data;
  modport slave(ref data, export Read);
  modport master(ref data, import task Read(input logic [7:0] raddr));
endinterface

module generic_mem(interface a);
  task a.Read(input logic [7:0] raddr);
    a.data = raddr + 1;
    $display("GREAD %0d", raddr);
  endtask
endmodule

module typed_mem(sb2.slave a);
  task a.Read(input logic [7:0] raddr);
    a.data = raddr + 1;
    $display("TREAD %0d", raddr);
  endtask
endmodule

module generic_cpu(sb2.master b);
  initial begin
    #1 b.Read(8'd4);
    $display("GDATA %0d", b.data);
  end
endmodule

module typed_cpu(sb2.master b);
  initial begin
    #1 b.Read(8'd4);
    $display("TDATA %0d", b.data);
  end
endmodule

module issue823_modport_export_provider;
  sb2 generic_ifc();
  sb2 typed_ifc();

  // Consumers precede providers to cover instance-order independence.
  generic_cpu generic_user(generic_ifc.master);
  typed_cpu typed_user(typed_ifc.master);
  generic_mem generic_provider(generic_ifc.slave);
  typed_mem typed_provider(typed_ifc.slave);
endmodule
