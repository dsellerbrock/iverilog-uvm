interface nested_rebind_if;
  logic [1:0] csb;
endinterface
class nested_rebind_cfg; virtual nested_rebind_if vif; endclass
class nested_rebind_dev;
  nested_rebind_cfg cfg;
  int active_csb;
  int wakes;
  task automatic wait_pos;
    @(posedge cfg.vif.csb[active_csb]);
    wakes++;
  endtask
endclass
module nested_rebind;
  nested_rebind_if old_bus(), middle_bus(), new_bus();
  nested_rebind_cfg old_cfg, new_cfg;
  nested_rebind_dev d;
  initial begin
    old_bus.csb=0; middle_bus.csb=0; new_bus.csb=0;
    old_cfg=new; old_cfg.vif=old_bus; new_cfg=new; new_cfg.vif=middle_bus;
    d=new; d.cfg=old_cfg; d.active_csb=1;
    fork d.wait_pos(); join_none
    #1 d.cfg=new_cfg; // equal selected value, but root subscription must move now
    old_bus.csb[1]=1;
    #1 if(d.wakes!=0) $fatal(1,"old cfg/VIF source woke");
    middle_bus.csb[1]=1;
    #1 if(d.wakes!=1) $fatal(1,"new cfg source missed");
    middle_bus.csb[1]=0;
    fork d.wait_pos(); join_none
    #1 begin
      new_cfg.vif=new_bus; // equal selected value; refresh before writer continues
      new_bus.csb[1]=1;
    end
    #1 if(d.wakes!=2) $fatal(1,"immediate new rebound VIF edge missed");
    new_bus.csb[1]=0;
    fork d.wait_pos(); join_none
    #1 middle_bus.csb[1]=1;
    #1 if(d.wakes!=2) $fatal(1,"old rebound VIF woke live waiter");
    new_bus.csb[1]=1;
    #1 if(d.wakes!=3) $fatal(1,"current rebound VIF missed");
    $display("PASS nested rebind"); $finish;
  end
endmodule
