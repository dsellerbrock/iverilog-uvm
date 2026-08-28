// IEEE 1800-2017/2023 23.11 / Syntax 23-9: a UDP is not a permitted bound
// instantiation. The UDP exists only in -y and the ordinary module target has
// no elaborated occurrence, so legality must be checked during bind resolution.
module sv_bind_library_udp_kind_target;
  logic in = 1'b0;
  wire out;
endmodule

bind sv_bind_library_udp_kind_target
  sv_bind_library_udp_kind_primitive bound_udp(out, in);

module sv_bind_library_udp_kind_fail;
endmodule
