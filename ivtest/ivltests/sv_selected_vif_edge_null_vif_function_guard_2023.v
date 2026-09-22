interface null_vif_function_guard_if; logic b; endinterface
module null_vif_function_guard;
 class cfg_t;
  virtual null_vif_function_guard_if vif;
  function int selector();
   if (vif == null) return 0;
   return vif.b;
  endfunction
 endclass
 cfg_t cfg; logic [1:0] data; int wakes;
 initial begin
  cfg=new;cfg.vif=null;data=0;
  fork begin @(data[cfg.selector()]);wakes++;end join_none
  #1 data[1]=1;
  #1 if(wakes!=0) $fatal(1,"guarded null selector woke on other bit");
  data[0]=1;
  #1 if(wakes!=1) $fatal(1,"guarded null selector missed selected bit");
  $display("PASS guarded null VIF function");$finish;
 end
 initial #20 $fatal(1,"guarded null VIF timeout");
endmodule
