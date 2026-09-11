// Explicit lifecycle recorder for original UVM 1.1 legacy APIs.
// This does not install a default recorder or implement typed attributes.
`ifndef IVL_UVM_LEGACY_RECORDER_SVH
`define IVL_UVM_LEGACY_RECORDER_SVH
package ivl_uvm_legacy_recording;
  import uvm_pkg::*;
  import "DPI-C" context function int ivl_uvm_record_open(input string filename);
  import "DPI-C" context function int ivl_uvm_record_open_text(input int owner,input string filename);
  import "DPI-C" context function int ivl_uvm_record_check_text(input int owner,fd);
  import "DPI-C" context function int ivl_uvm_record_stream(input int owner,h,input string name,kind,scope);
  import "DPI-C" context function int ivl_uvm_record_begin(input int owner,h,stream,input string kind,name,label,desc,input longint unsigned begin_time);
  import "DPI-C" context function int ivl_uvm_record_link(input int owner,left_h,right_h,input string relation);
  import "DPI-C" context function int ivl_uvm_record_end(input int owner,h,input longint unsigned end_time);
  import "DPI-C" context function int ivl_uvm_record_free(input int owner,h);
  import "DPI-C" context function int ivl_uvm_record_kind(input int owner,h,input string kind);

  class ivl_uvm_legacy_recorder extends uvm_recorder;
    protected int native_owner;
    protected string text_path;

    function new(string name, string journal);
      super.new(name);
      text_path = {journal,".uvm.log"};
      filename = text_path;
      native_owner = ivl_uvm_record_open(journal);
      if (native_owner <= 0) $fatal(1,"Cannot create native recording journal");
      file = ivl_uvm_record_open_text(native_owner,text_path);
      if (file == 0)
        $fatal(1,"Cannot create legacy recording text log");
    endfunction

    virtual function string get_type_name();
      return "ivl_uvm_legacy_recorder";
    endfunction

    virtual function bit open_file();
      if (filename != text_path) $fatal(1,"Cannot change an active recorder's text destination");
      if (!ivl_uvm_record_check_text(native_owner,file)) $fatal(1,"Legacy recording text log failed");
      return 1;
    endfunction

    virtual function integer create_stream(string name,string t,string scope);
      int h = super.create_stream(name,t,scope);
      if (h <= 0) return h;
      if (!ivl_uvm_record_stream(native_owner,h,name,t,scope)) begin
        // Roll back membership even when journal failure poisoned this owner.
        m_handles.delete(h);
        $fatal(1,"Cannot register native recording stream");
      end
      return h;
    endfunction

    virtual function integer begin_tr(string txtype,integer stream,string nm,
                                      string label="",string desc="",time begin_time=0);
      int h;
      if (!ivl_uvm_record_kind(native_owner,stream,"Fiber"))
        $fatal(1,"Transaction requires a stream owned by this recorder");
      h = super.begin_tr(txtype,stream,nm,label,desc,begin_time);
      if (h <= 0) return h;
      if (!ivl_uvm_record_begin(native_owner,h,stream,txtype,nm,label,desc,begin_time)) begin
        // Roll back membership even when journal failure poisoned this owner.
        m_handles.delete(h);
        $fatal(1,"Cannot register native recording transaction");
      end
      return h;
    endfunction

    virtual function integer check_handle_kind(string htype,integer handle);
      return ivl_uvm_record_kind(native_owner,handle,htype);
    endfunction

    virtual function void end_tr(integer handle,time end_time=0);
      if (!ivl_uvm_record_end(native_owner,handle,end_time))
        $fatal(1,"Cannot end native recording transaction");
      super.end_tr(handle,end_time);
    endfunction

    virtual function void link_tr(integer h1,integer h2,string relation="");
      if (!ivl_uvm_record_link(native_owner,h1,h2,relation))
        $fatal(1,"Cannot link native recording transactions");
      super.link_tr(h1,h2,relation);
    endfunction

    virtual function void free_tr(integer handle);
      if (!ivl_uvm_record_free(native_owner,handle))
        $fatal(1,"Cannot free native recording handle");
      super.free_tr(handle);
    endfunction
  endclass
endpackage
`endif
