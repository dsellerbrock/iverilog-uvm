interface csrng_if;
  logic cmd_req;
endinterface

module scalar_collision_control;
  wire csrng_cmd_req;
  csrng_if csrng_if();
  assign csrng_cmd_req = csrng_if.cmd_req;
endmodule
