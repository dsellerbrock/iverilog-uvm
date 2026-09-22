module sv_whole_function_event_null_nested_negative;
 class child_t;
  int value;
  function int read_value(); return value; endfunction
 endclass
 class cfg_t;
  child_t child;
  function int read_value();
   int value=child.read_value();
   $display("ILLEGAL_AFTER_ERROR");
   return value;
  endfunction
 endclass
 cfg_t cfg;
 initial begin
  cfg=new;
  @(cfg.read_value());
  $display("ILLEGAL_AFTER_ERROR");
  $fatal(1,"null event continued");
 end
endmodule
