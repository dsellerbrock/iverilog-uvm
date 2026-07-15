package p1;
  int pv = 77;
endpackage

interface ifc;
  logic [7:0] data;
  modport mon (input data);
  modport drv (output data);
endinterface

module top;
  ifc bus0();
  initial begin
    bus0.data = 8'h2A;
    #1 $m12_scopes;
  end
endmodule
