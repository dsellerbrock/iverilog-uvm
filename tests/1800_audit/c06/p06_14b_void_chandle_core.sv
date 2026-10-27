module p06_14b;
  int pass=0, fail=0;
  task automatic ck(input string id,input bit c); if(c) pass++; else begin fail++; $display("FAIL %s",id); end endtask
  class H; chandle p; endclass
  chandle ch,c2,am[int]; H h; int cnt=0;
  function void fv(); cnt++; endfunction
  function int gi(); cnt++; return 7; endfunction
  function chandle id(chandle c); return c; endfunction
  initial begin
    ck("default_null",ch==null && !ch && ch===null);
    c2=ch; ck("assign_chandle",c2==ch && c2===ch && !(c2!=ch));
    c2=null; ck("assign_null",c2==null);
    if(ch) ck("bool_true_for_null",0); else ck("bool_null",1);
    am[1]=ch; ck("assoc_value",am[1]==null);
    ck("fn_pass_return",id(ch)==null);
    h=new; ck("class_member_default",h.p==null);
    fv(); void'(gi()); ck("void_calls",cnt==2);
    $display("RESULT pass=%0d fail=%0d",pass,fail);
  end
endmodule
