typedef struct packed {
  logic genbits_ready;
  logic [31:0] csrng_req_bus;
  logic csrng_req_valid;
} req_t;

interface req_if;
  bit if_mode;
  logic ready_int;
  logic [31:0] bus_int;
  logic valid_int;
  wire req_t cmd_req;
  assign cmd_req.genbits_ready = if_mode ? ready_int : 'z;
  assign cmd_req.csrng_req_bus = if_mode ? bus_int : 'z;
  assign cmd_req.csrng_req_valid = if_mode ? valid_int : 'z;
endinterface

module packed_interface_probe;
  req_if intf[2]();
  wire req_t [1:0] csrng_cmd_req;
  wire [1:0] genbits_stage_rdy;
  for (genvar i = 0; i < 2; i++) begin
    assign csrng_cmd_req[i] = intf[i].cmd_req;
    assign genbits_stage_rdy[i] = csrng_cmd_req[i].genbits_ready;
  end
  initial begin
    intf[0].if_mode = 1;
    intf[1].if_mode = 1;
    intf[0].ready_int = 1;
    intf[1].ready_int = 0;
    #1;
    if (genbits_stage_rdy !== 2'b01) $fatal(1, "bad ready %b", genbits_stage_rdy);
    $display("PASS packed interface: %b", genbits_stage_rdy);
    $finish(0);
  end
endmodule
