// Reduced from the released CSRNG csrng_if / push_pull_if ready-valid wiring.
// A packed field passes through two conditional tri-state drivers and back.
typedef struct packed { logic valid; } cmd_t;

interface csrng_loop_if #(parameter bit FEEDBACK = 1);
  bit if_mode;
  bit pin_mode;
  bit is_push_agent;
  logic valid_int;
  wire cmd_t cmd_req;
  wire valid;

  assign valid = (is_push_agent && pin_mode == 1'b1) ? valid_int : 'z;
  if (FEEDBACK) begin
    assign valid = (if_mode == 1'b0) ? cmd_req.valid : 'z;
  end
  assign cmd_req.valid = (if_mode == 1'b1) ? valid : 'z;
endinterface

module packed_tri_red;
  csrng_loop_if #(.FEEDBACK(1)) intf();
  initial begin
    intf.if_mode = 1;
    intf.pin_mode = 1;
    intf.is_push_agent = 1;
    intf.valid_int = 1;
    #1;
    $display("PASS red reached time one: %b", intf.cmd_req.valid);
    $finish(0);
  end
endmodule

module packed_tri_control;
  csrng_loop_if #(.FEEDBACK(0)) intf();
  initial begin
    intf.if_mode = 1;
    intf.pin_mode = 1;
    intf.is_push_agent = 1;
    intf.valid_int = 1;
    #1;
    if (intf.cmd_req.valid !== 1'b1) $fatal(1, "bad valid: %b", intf.cmd_req.valid);
    $display("PASS control reached time one: %b", intf.cmd_req.valid);
    $finish(0);
  end
endmodule
