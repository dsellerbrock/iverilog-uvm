module sv_nettype_unresolved_select_driver_fail;
  typedef struct {
    logic flag;
    logic [3:0] payload;
  } record_t;

  nettype record_t record_net;
  nettype logic [7:0] vector_net;

  record_net member_data;
  vector_net bit_data;
  vector_net part_data;

  assign member_data.flag = 1'b1;
  assign bit_data[0] = 1'b1;
  assign part_data[3:0] = 4'ha;
endmodule
