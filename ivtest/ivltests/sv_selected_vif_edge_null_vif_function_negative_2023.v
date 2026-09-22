interface null_vif_function_negative_if; logic b; endinterface
module null_vif_function_negative;
 class cfg_t;
  virtual null_vif_function_negative_if vif;
  function int selector(); return vif.b; endfunction
 endclass
 cfg_t cfg; logic [1:0] data;
 initial begin
  cfg=new;cfg.vif=null;data=0;
  @(data[cfg.selector()]);
  $display("ILLEGAL_AFTER_NULL");
 end
endmodule
