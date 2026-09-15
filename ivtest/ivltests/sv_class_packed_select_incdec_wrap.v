module sv_class_packed_select_incdec_wrap;
 class holder; logic signed [15:0] value; endclass
 holder object; int result; int calls;
 function automatic int index(); calls++; return 4; endfunction
 initial begin
  object=new; object.value=16'ha50a; calls=0;
  result=object.value[index()+:4]--;
  if(result!==0 || object.value!==16'ha5fa || calls!=1) $fatal(1,"postfix decrement wrap");
  object.value=16'haf0a; calls=0;
  result=--object.value[index()+:4];
  if(result!==15 || object.value!==16'haffa || calls!=1) $fatal(1,"prefix decrement selected unsigned result");
  object.value=16'h55aa; calls=0;
  result=object.value[index()]--;
  if(result!==0 || object.value!==16'h55ba || calls!=1) $fatal(1,"postfix bit decrement wrap");
  $display("PASSED");
 end
endmodule
