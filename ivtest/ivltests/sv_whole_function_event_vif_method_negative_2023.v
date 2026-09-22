// Unsupported-boundary probe only: this must not be recorded as a functional pass.
interface whole_function_event_vif_if;
  logic selector_bit;
endinterface
module sv_whole_function_event_vif_method_negative;
  class cfg_t;
    virtual whole_function_event_vif_if vif;
    function automatic int selector(); return vif.selector_bit; endfunction
  endclass
  whole_function_event_vif_if bus();
  cfg_t cfg;
  logic [1:0] data;
  initial begin
    cfg = new; cfg.vif = bus; data = '0;
    @(data[cfg.selector()]);
    $fatal(1, "VIF method probe unexpectedly reached event body");
  end
endmodule
