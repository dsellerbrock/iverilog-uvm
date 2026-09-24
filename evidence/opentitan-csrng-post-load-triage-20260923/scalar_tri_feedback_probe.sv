interface scalar_loop_if;
  bit if_mode;
  bit pin_mode;
  bit is_push_agent;
  logic valid_int;
  wire valid;
  wire cmd_req;
  assign valid = (if_mode == 1'b0) ? cmd_req : 'z;
  assign cmd_req = (if_mode == 1'b1) ? valid : 'z;
  assign valid = (is_push_agent && pin_mode == 1'b1) ? valid_int : 'z;
endinterface

module scalar_tri_feedback_probe;
  scalar_loop_if intf();
  initial begin
    intf.if_mode = 1;
    intf.pin_mode = 1;
    intf.is_push_agent = 1;
    intf.valid_int = 1;
    #1;
    $display("PASS scalar reached time one: %b", intf.cmd_req);
    $finish(0);
  end
endmodule
