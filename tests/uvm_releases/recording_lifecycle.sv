module main;
  import "DPI-C" context function int ivl_uvm_record_open(input string filename);
  import "DPI-C" context function int ivl_uvm_record_stream(input int owner,h,input string name,kind,scope);
  import "DPI-C" context function int ivl_uvm_record_begin(input int owner,h,stream,input string kind,name,label,desc,input longint unsigned begin_time);
  import "DPI-C" context function int ivl_uvm_record_link(input int owner,left_h,right_h,input string relation);
  import "DPI-C" context function int ivl_uvm_record_end(input int owner,h,input longint unsigned end_time);
  import "DPI-C" context function int ivl_uvm_record_free(input int owner,h);
  import "DPI-C" context function int ivl_uvm_record_kind(input int owner,h,input string kind);
  import "DPI-C" context function int ivl_uvm_record_open_text(input int owner,input string filename);
  import "DPI-C" context function int ivl_uvm_record_check_text(input int owner,fd);
  int a,b,c,text_fd;
  initial begin
    a=ivl_uvm_record_open("a.jsonl");
    if ($test$plusargs("io_failure")) begin
      if(a<=0) $fatal(1,"owner allocation before I/O failure");
      if(ivl_uvm_record_stream(a,1,"long stream name","TVM","scope")) $fatal(1,"write failure accepted");
      if(ivl_uvm_record_stream(a,2,"second","TVM","scope")) $fatal(1,"poisoned owner accepted");
      $display("POISON_REJECTED");
      $finish;
    end
    b=ivl_uvm_record_open("b.jsonl");
    if(a<=0 || b<=0 || a==b) $fatal(1,"owner allocation");
    if(!ivl_uvm_record_stream(a,1,"a\n\"\\name","TVM","scope") || !ivl_uvm_record_stream(b,2,"b","TVM","scope")) $fatal(1,"streams");
    if(!ivl_uvm_record_begin(a,3,1,"transaction","parent","label","desc",64'hfffffffffffffff0)) $fatal(1,"begin parent");
    if(!ivl_uvm_record_begin(b,4,2,"transaction","child","label","desc",64'hfffffffffffffff1)) $fatal(1,"begin child");
    if(!ivl_uvm_record_kind(b,3,"Transaction") || ivl_uvm_record_kind(b,1,"Fiber")) $fatal(1,"kind/ownership");
    if(!ivl_uvm_record_link(b,3,4,"child")) $fatal(1,"cross-owner child link");
    if(!ivl_uvm_record_end(a,3,64'hfffffffffffffff2)) $fatal(1,"end");
    if(ivl_uvm_record_begin(a,3,1,"duplicate","bad","","",0)) $fatal(1,"ended handle reused");
    if(!ivl_uvm_record_link(b,4,3,"ended parent")) $fatal(1,"ended link");
    if(ivl_uvm_record_end(b,3,0) || ivl_uvm_record_end(a,1,0) || ivl_uvm_record_end(a,3,0)) $fatal(1,"invalid end accepted");
    if(!ivl_uvm_record_free(a,3) || ivl_uvm_record_kind(a,3,"Transaction")) $fatal(1,"free");
    if(ivl_uvm_record_link(b,4,3,"freed") || ivl_uvm_record_free(a,3)) $fatal(1,"freed accepted");
    if(!ivl_uvm_record_free(b,4) || !ivl_uvm_record_free(a,1) || !ivl_uvm_record_free(b,2)) $fatal(1,"remaining free");
    if(ivl_uvm_record_open("a.jsonl") || ivl_uvm_record_open("missing/path.jsonl")) $fatal(1,"file failure accepted");
    c=ivl_uvm_record_open("c.jsonl");
    if(c<=0) $fatal(1,"text owner");
    if(ivl_uvm_record_open_text(c,"a.jsonl")) $fatal(1,"existing text destination accepted");
    text_fd=ivl_uvm_record_open_text(c,"c.log");
    if(!text_fd) $fatal(1,"text descriptor");
    $fdisplay(text_fd,"retained text");
    if(!ivl_uvm_record_check_text(c,text_fd)) $fatal(1,"text flush");
    $display("PASSED");
  end
endmodule
