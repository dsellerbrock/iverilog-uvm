module sv_nettype_lookup_fail;
  nettype missing_net alias_net;
  nettype logic resolved_net with missing_resolver;
endmodule
