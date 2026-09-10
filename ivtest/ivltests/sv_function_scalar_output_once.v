// IEEE1800-2017/2023 13.5: output actual evaluated only for return copy.
module sv_function_scalar_output_once;
 int calls=0;
 int selected=0;
 int slots[2];
 function automatic int index_value(); calls++;return selected;endfunction
 function automatic int produce(output int value);selected=1;value=37;return 0;endfunction
 initial begin
  int ignored;
  slots[0]=-1;slots[1]=-1;
  ignored=produce(slots[index_value()]);
  if(calls!=1 || slots[0]!=-1 || slots[1]!=37)
   $fatal(1,"output calls=%0d slots=%0d,%0d",calls,slots[0],slots[1]);
  $display("PASSED");
 end
endmodule
