`timescale 1ns/1ps

typedef struct packed { logic valid; } startup_cmd_t;

interface startup_feedback_if;
  bit if_mode = 1'b1;
  bit pin_mode = 1'b1;
  bit is_push_agent = 1'b1;
  logic valid_int = 1'b1;
  wire startup_cmd_t cmd_req;
  wire valid;

  assign valid = (is_push_agent && pin_mode == 1'b1) ? valid_int : 'z;
  assign valid = (if_mode == 1'b0) ? cmd_req.valid : 'z;
  assign cmd_req.valid = (if_mode == 1'b1) ? valid : 'z;
endinterface

module sv_packed_tri_startup_slot;
  startup_feedback_if intf();
  wire constant_one = 1'b1;
  wire forwarded_one = constant_one;

  initial begin
    // The feedback may already be active when this time-zero process runs.
    // The process must still reach its inactive-region continuation.
    #0;
    if (intf.cmd_req.valid !== 1'b1 || forwarded_one !== 1'b1)
      $fatal(1, "time-zero feedback or constant propagation failed");
    #1;
    if (intf.cmd_req.valid !== 1'b1)
      $fatal(1, "feedback changed after time advanced");
    $display("PASSED");
    $finish(0);
  end
endmodule
