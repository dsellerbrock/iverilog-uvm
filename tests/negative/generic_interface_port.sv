// M5-if recorded corner: a GENERIC `interface` port takes its type from
// the connected instance, which needs per-instantiation port typing the
// elaborator does not do yet. Must be a loud sorry (was a bare
// "syntax error / Errors in port declarations").
interface pif; logic x; endinterface
module m(interface b);          // sorry: generic interface port
  initial b.x = 1;
endmodule
module generic_interface_port;
  pif p();
  m mm(p);
endmodule
