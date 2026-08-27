// IEEE 1800-2017/2023 23.11 / Syntax 23-9: a UDP instantiation is not a
// permitted bound-instantiation form. The interface target also proves that
// a primitive is not mistaken for the interface/checker exception.
primitive sv_bind_interface_udp_primitive(output out, input in);
  table
    0 : 0;
    1 : 1;
  endtable
endprimitive

interface sv_bind_interface_udp_target;
  logic in = 1'b0;
  wire out;
endinterface

bind sv_bind_interface_udp_target sv_bind_interface_udp_primitive
  bound_udp(out, in);

module sv_bind_interface_udp_fail;
  sv_bind_interface_udp_target target();
endmodule
