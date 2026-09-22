module sv_class_event_list_invalid_member;
  class cfg_t;
    logic present;
  endclass
  cfg_t cfg;
  logic pulses;
  initial begin
    cfg = new;
    @(cfg.absent, pulses);
  end
endmodule
