interface i; modport s(export task Read(input logic [7:0] x)); endinterface module m(interface a); task a.Read(input logic [3:0] x); endtask endmodule module top; i ii(); m u(ii.s); endmodule
