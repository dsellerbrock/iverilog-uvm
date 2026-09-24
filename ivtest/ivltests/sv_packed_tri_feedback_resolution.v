`include "ivltests/sv_packed_tri_feedback_converge.v"

typedef struct packed { logic [1:0] bits; } packed_tri_pair_t;

interface packed_tri_pair_if;
  wire packed_tri_pair_t payload;
  logic low_drive;
  logic high_drive;
  assign payload.bits[0] = low_drive;
  assign payload.bits[1] = high_drive;
endinterface

module sv_packed_tri_feedback_resolution;
  packed_tri_feedback_if #(.FEEDBACK(0)) no_feedback();
  packed_tri_pair_if partial();
  logic first_drive, second_drive;
  logic weak_enable, strong_enable;
  wire conflict;
  wire strength_net;
  string weak_strength, strong_strength;

  assign conflict = first_drive;
  assign conflict = second_drive;
  assign (weak1, weak0) strength_net = weak_enable ? 1'b1 : 1'bz;
  assign (strong1, strong0) strength_net = strong_enable ? 1'b1 : 1'bz;

  initial begin
    no_feedback.if_mode = 1;
    no_feedback.pin_mode = 1;
    no_feedback.is_push_agent = 1;
    no_feedback.valid_int = 1;
    partial.low_drive = 0;
    partial.high_drive = 1;
    first_drive = 1'bz;
    second_drive = 1'bz;
    weak_enable = 1;
    strong_enable = 0;
    #1;
    if (no_feedback.cmd_req.valid !== 1'b1 || partial.payload.bits !== 2'b10 ||
        conflict !== 1'bz || strength_net !== 1'b1)
      $fatal(1, "initial value or partial field failed");
    weak_strength = $sformatf("%v", strength_net);

    // The same logic value must retain a changed drive strength.
    strong_enable = 1;
    partial.low_drive = 1;
    first_drive = 1'b1;
    second_drive = 1'b0;
    #1;
    strong_strength = $sformatf("%v", strength_net);
    if (weak_strength == strong_strength || partial.payload.bits !== 2'b11 ||
        conflict !== 1'bx)
      $fatal(1, "strength change, partial update, or conflict was lost");

    // Identical input and an X-to-Z boundary must both settle.
    partial.low_drive = 1;
    first_drive = 1'bx;
    second_drive = 1'bz;
    #1;
    if (partial.payload.bits !== 2'b11 || conflict !== 1'bx)
      $fatal(1, "equal partial input or X/Z resolution failed");
    first_drive = 1'bz;
    #1;
    if (conflict !== 1'bz)
      $fatal(1, "all-Z resolution failed");

    $display("PASSED");
    $finish(0);
  end
endmodule
