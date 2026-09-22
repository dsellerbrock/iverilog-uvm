// Expected compile rejection: a bit-select index must be integral; a method returning real is not.
module sv_whole_function_event_real_negative;
  class cfg_t;
    function automatic real selector(); return 0.0; endfunction
  endclass
  cfg_t cfg = new;
  logic [1:0] data;
  initial @(data[cfg.selector()]);
endmodule
