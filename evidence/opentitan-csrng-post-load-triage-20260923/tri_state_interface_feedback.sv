typedef struct packed {
  logic ready;
  logic [31:0] bus;
  logic valid;
} cmd_t;

interface pin_if;
  bit if_mode;
  bit is_push_agent;
  logic valid_int;
  logic [31:0] h_data_int;
  logic ready_int;
  wire valid;
  wire [31:0] h_data;
  wire ready;
  assign valid = (is_push_agent && if_mode) ? valid_int : 'z;
  assign h_data = if_mode ? h_data_int : 'z;
  assign ready = (is_push_agent && !if_mode) ? ready_int : 'z;
endinterface

interface cmd_if;
  bit if_mode;
  wire cmd_t cmd_req;
  pin_if pin();
  assign pin.valid = (if_mode == 1'b0) ? cmd_req.valid : 'z;
  assign pin.h_data = (if_mode == 1'b0) ? cmd_req.bus : 'z;
  assign pin.ready = (if_mode == 1'b0) ? cmd_req.ready : 'z;
  assign cmd_req.valid = (if_mode == 1'b1) ? pin.valid : 'z;
  assign cmd_req.bus = (if_mode == 1'b1) ? pin.h_data : 'z;
  assign cmd_req.ready = (if_mode == 1'b1) ? pin.ready : 'z;
endinterface

module tri_state_interface_feedback;
  cmd_if intf[2]();
  wire cmd_t [1:0] csrng_cmd_req;
  wire [1:0] stage_ready;
  for (genvar i = 0; i < 2; i++) begin
    assign csrng_cmd_req[i] = intf[i].cmd_req;
    assign stage_ready[i] = csrng_cmd_req[i].ready;
  end
  initial begin
    intf[0].if_mode = 1;
    intf[1].if_mode = 0;
    intf[0].pin.if_mode = 1;
    intf[1].pin.if_mode = 0;
    intf[0].pin.is_push_agent = 1;
    intf[1].pin.is_push_agent = 1;
    intf[0].pin.valid_int = 1;
    intf[0].pin.h_data_int = 32'h1234;
    intf[1].pin.ready_int = 1;
    #1;
    $display("PASS reached time one: %b", stage_ready);
    $finish(0);
  end
endmodule
