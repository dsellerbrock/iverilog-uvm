// IEEE1800-2017/2023 7.4.6,13.5: invalid indexed writes do not modify storage.
module sv_fixed_property_output_invalid;
 class Box; int slots[2]; endclass
 int calls=0,index_calls=0,selection=0;
 function automatic logic[63:0] index_value();
  index_calls++;
  case(selection)
   0:return 64'hffffffffffffffff;
   1:return 2;
   2:return 'x;
   default:return 64'h100000000;
  endcase
 endfunction
 function automatic int produce(output int value);calls++;value=37;return 0;endfunction
 initial begin
  Box b;int ignored;
  b=new;b.slots[0]=-1;b.slots[1]=-1;
  for(selection=0;selection<4;selection++)begin
   ignored=produce(b.slots[index_value()]);
   if(b.slots[0]!=-1 || b.slots[1]!=-1)$fatal(1,"invalid write");
  end
  if(calls!=4 || index_calls!=4)$fatal(1,"invalid side effects");
  ignored=produce(b.slots[0]);
  if(b.slots[0]!=37 || b.slots[1]!=-1)$fatal(1,"valid after invalid");
  $display("PASSED");
 end
endmodule
