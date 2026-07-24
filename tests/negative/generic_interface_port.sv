// M5-5 residual: generic `interface` ports are supported (typed per
// instantiation from the actual — see sv_generic_interface_port), but
// the ACTUAL must be an interface instance (or instance.modport, or a
// forwarded interface formal). A plain net/variable actual must stay
// a loud error, never a silently mistyped handle.
interface pif; logic x; endinterface
module m(interface b);
  initial b.x = 1;
endmodule
module generic_interface_port;
  wire w;
  m mm(w);          // error: actual is not an interface instance
endmodule
