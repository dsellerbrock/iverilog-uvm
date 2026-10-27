interface i; modport mp(import task Read(input logic [7:0] x)); task Read(input logic [3:0] x); endtask endinterface module m(i.mp b); endmodule module top; i ii(); m u(ii.mp); endmodule
