// IEEE 1800-2017/2023 23.11 / Syntax 23-9: primitive/UDP instantiation is
// not a permitted bound-instantiation form, including for an ordinary module
// target where interface-specific legality cannot mask the general rule.
primitive sv_bind_module_udp_primitive(output out, input in);
  table
    0 : 0;
    1 : 1;
  endtable
endprimitive

module sv_bind_module_udp_target;
  logic in = 1'b0;
  wire out;
endmodule

bind sv_bind_module_udp_target sv_bind_module_udp_primitive bound_udp(out, in);

module sv_bind_module_udp_fail;
  sv_bind_module_udp_target target();
endmodule
