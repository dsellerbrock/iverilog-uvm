`timescale 1ns/1ps

typedef struct packed { logic valid; } packed_tri_cmd_t;

interface packed_tri_feedback_if #(parameter bit FEEDBACK = 1);
  bit if_mode;
  bit pin_mode;
  bit is_push_agent;
  logic valid_int;
  wire packed_tri_cmd_t cmd_req;
  wire valid;

  assign valid = (is_push_agent && pin_mode == 1'b1) ? valid_int : 'z;
  if (FEEDBACK) begin
    assign valid = (if_mode == 1'b0) ? cmd_req.valid : 'z;
  end
  assign cmd_req.valid = (if_mode == 1'b1) ? valid : 'z;
endinterface

module sv_packed_tri_feedback_converge;
  packed_tri_feedback_if #(.FEEDBACK(1)) intf();
  initial begin
    intf.if_mode = 1;
    intf.pin_mode = 1;
    intf.is_push_agent = 1;
    intf.valid_int = 1;
    #1;
    if (intf.cmd_req.valid !== 1'b1)
      $fatal(1, "feedback did not resolve to driven one");
    $display("PASSED");
    $finish(0);
  end
endmodule
