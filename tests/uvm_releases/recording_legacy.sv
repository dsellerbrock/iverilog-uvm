`include "uvm_legacy_recorder.svh"
module main;
  import uvm_pkg::*;
  import ivl_uvm_legacy_recording::*;
  class transaction extends uvm_transaction;
    function new(string name); super.new(name); endfunction
  endclass
  class component_type extends uvm_component;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
  endclass
  initial begin
    ivl_uvm_legacy_recorder a,b;
    uvm_recorder saved_default;
    transaction parent_tx,child_tx,component_tx;
    component_type component;
    int parent_h,child_h,component_h,transaction_h;
    string replace_command;
    int switched_h,switched_transaction;
    saved_default=uvm_default_recorder;
    a=new("a","legacy-a.jsonl");
    b=new("b","legacy-b.jsonl");
    if ($value$plusargs("replace_text=%s",replace_command))
      if ($system(replace_command) != 0) $fatal(1,"Cannot replace test pathname");
    if ($test$plusargs("rollback")) begin
      if ($test$plusargs("rollback_transaction")) begin
        switched_h=a.create_stream("valid","test","");
        if (!ivl_uvm_record_stream(1,2,"collision","test","")) $fatal(1,"Cannot set up transaction collision");
        switched_transaction=a.begin_tr("test",switched_h,"rejected");
      end else begin
        if (!$test$plusargs("rollback_io") && !ivl_uvm_record_stream(1,1,"collision","test","")) $fatal(1,"Cannot set up collision");
        switched_h=a.create_stream("rejected","test","");
      end
      $fatal(1,"Registration failure returned");
    end
    if(uvm_default_recorder != saved_default) $fatal(1,"default recorder replaced");
    parent_tx=new("parent"); child_tx=new("child");
    parent_tx.enable_recording("parent-stream",a);
    child_tx.enable_recording("child-stream",b);
    parent_h=parent_tx.begin_tr(10);
    child_h=child_tx.begin_child_tr(11,parent_h);
    if(parent_h<=0 || child_h<=0 || parent_h==child_h) $fatal(1,"child handles");
    parent_tx.end_tr(12,0);
    b.link_tr(child_h,parent_h,"after_end");
    child_tx.end_tr(13,1);
    a.free_tr(parent_h);
    component=new("component",null);
    component.recorder=b;
    component.recording_detail=UVM_FULL;
    component_tx=new("component-tx");
    component_tx.enable_recording("transaction-stream",a);
    component_h=component.begin_tr(component_tx,"component-stream","label","description",20);
    transaction_h=component_tx.get_tr_handle();
    if(component_h<=0 || transaction_h<=0 || component_h==transaction_h) $fatal(1,"component handles");
    if ($test$plusargs("wrong_owner")) component.recorder=a;
    component.end_tr(component_tx,21,1);
    if(a.check_handle_kind("Transaction",transaction_h) || b.check_handle_kind("Transaction",component_h)) $fatal(1,"component handles not freed");
    if(uvm_recorder::m_handles.exists(parent_h) || uvm_recorder::m_handles.exists(child_h) || uvm_recorder::m_handles.exists(transaction_h) || uvm_recorder::m_handles.exists(component_h)) $fatal(1,"superclass membership not freed");
    if(uvm_default_recorder != saved_default || component.recorder != b) $fatal(1,"recorder selection changed");
    if ($test$plusargs("switch_recorder")) begin
      component.recorder=a;
      switched_h=component.begin_tr(component_tx,"component-stream","","",30);
      switched_transaction=component_tx.get_tr_handle();
      if(switched_h<=0 || switched_transaction<=0) $fatal(1,"switch handles");
      component.end_tr(component_tx,31,1);
      if(uvm_recorder::m_handles.exists(switched_h) || uvm_recorder::m_handles.exists(switched_transaction)) $fatal(1,"switch membership not freed");
      $display("SWITCH_PASSED component=%0d transaction=%0d",switched_h,switched_transaction);
    end
    $display("LEGACY_RECORDING_PASSED parent=%0d child=%0d component=%0d transaction=%0d",parent_h,child_h,component_h,transaction_h);
    $finish;
  end
  final begin
    if ($test$plusargs("rollback")) begin
      if (uvm_recorder::m_handles.exists($test$plusargs("rollback_transaction") ? 2 : 1)) $display("ROLLBACK_FAILED");
      else $display("ROLLBACK_PASSED");
    end
  end
endmodule
