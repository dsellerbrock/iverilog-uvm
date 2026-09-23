package csrng_renamed_pkg;
  parameter int NUM_HW_APPS = 2;
  typedef struct packed {
    logic valid;
    logic [3:0] data;
  } csrng_req_t;
endpackage

interface csrng_if(input wire clk, input wire rst_n);
  import csrng_renamed_pkg::*;
  wire csrng_req_t cmd_req;
endinterface

module renamed_instance_control;
  import csrng_renamed_pkg::*;
  wire clk, rst_n;
  csrng_req_t [NUM_HW_APPS-1:0] csrng_cmd_req;
  csrng_if csrng_bus[NUM_HW_APPS](.clk(clk), .rst_n(rst_n));
  for (genvar i = 0; i < NUM_HW_APPS; i++) begin : gen_csrng_if
    assign csrng_cmd_req[i] = csrng_bus[i].cmd_req;
  end
endmodule
