module sv_whole_function_event_static_member;
 class cfg_t;
  static int value;
  function int value_fn(); return value; endfunction
 endclass
 cfg_t cfg;
 bit woke;
 initial begin
  cfg=new;cfg.value=0;
  fork begin @(cfg.value_fn());woke=1;end join_none
  #1 cfg.value=1;
  #1 if(!woke) $fatal(1,"static member read in method did not wake");
  $display("PASS static method member");$finish(0);
 end
endmodule
