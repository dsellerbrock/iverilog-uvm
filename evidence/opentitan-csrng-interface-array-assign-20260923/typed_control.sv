package csrng_min_pkg;
  parameter int NUM_HW_APPS = 2;
  typedef struct packed {
    logic valid;
    logic [3:0] data;
  } csrng_req_t;
endpackage

interface csrng_min_if(input wire clk, input wire rst_n);
  import csrng_min_pkg::*;
  wire csrng_req_t cmd_req;
endinterface

module typed_control;
  import csrng_min_pkg::*;
  wire clk, rst_n;
  csrng_req_t [NUM_HW_APPS-1:0] csrng_cmd_req;
  csrng_min_if csrng_if[NUM_HW_APPS](.clk(clk), .rst_n(rst_n));
  for (genvar i = 0; i < NUM_HW_APPS; i++) begin : gen_csrng_if
    assign csrng_cmd_req[i] = csrng_if[i].cmd_req;
  end
endmodule
