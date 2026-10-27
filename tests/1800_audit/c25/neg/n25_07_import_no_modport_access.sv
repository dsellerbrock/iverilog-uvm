interface i; modport a(import task t1); task t1; endtask task t2; endtask endinterface module m(i.a b); initial b.t2; endmodule module top; i ii(); m u(ii.a); endmodule
