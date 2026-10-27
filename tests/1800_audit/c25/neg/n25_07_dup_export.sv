interface i; modport s(export Read); endinterface module m(interface a); task a.Read; endtask endmodule module top; i ii(); m m1(ii.s); m m2(ii.s); endmodule
