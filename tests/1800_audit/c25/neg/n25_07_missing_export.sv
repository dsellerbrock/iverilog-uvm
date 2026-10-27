interface i; modport s(export Read); endinterface module m(interface a); endmodule module top; i ii(); m u(ii.s); endmodule
