module sv_nettype_invalid_underlying_fail;
  typedef int dynamic_array_t[];
  typedef int queue_t[$];

  nettype string string_net;
  nettype chandle chandle_net;
  nettype dynamic_array_t dynamic_array_net;
  nettype queue_t queue_net;
endmodule
