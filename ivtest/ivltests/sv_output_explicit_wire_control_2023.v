package types;
 typedef struct packed {logic p; logic n;} pair_t;
endpackage
interface bus_if;
 wire types::pair_t response;
 types::pair_t response_int;
 logic active;
 assign response=active ? response_int : 'z;
endinterface
module source(input logic a,b,output wire types::pair_t o);
 assign o.p=a;assign o.n=b;
endmodule
module wrapper(input logic a,b,output wire types::pair_t o);
 source s(a,b,o);
endmodule
module test;
 bus_if bus(); logic a,b;
 wrapper w(a,b,bus.response);
 initial begin
  bus.active=0;bus.response_int=2'b01;a=1;b=0;#1;
  if(bus.response!==2'b10) $fatal(1,"inactive external driver");
  bus.active=1;#1;
  if(bus.response!==2'bxx) $fatal(1,"resolved conflicting drivers");
  if(w.s.o!==2'bxx || w.o!==2'bxx) $fatal(1,"external resolution leaked into variable output: %b %b",w.s.o,w.o);
  bus.active=0;a=0;b=1;#1;
  if(bus.response!==2'b01) $fatal(1,"driver release");
  $display("PASSED resolved interface ports");
 end
endmodule
