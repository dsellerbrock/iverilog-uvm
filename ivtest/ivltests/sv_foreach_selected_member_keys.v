class token;
 int id;
 function new(int n); id=n; endfunction
 function int number(); return id; endfunction
endclass
class bucket;
 typedef shortint key_t;
 int narrow[key_t];
 int objects[token];
endclass
module main;
 bucket boxes[2];
 token a,b;
 int selector=1, count, sum, seen;
 initial begin
  boxes[0]=new; boxes[1]=new; a=new(1); b=new(2);
  boxes[0].narrow[0]=99;
  boxes[1].narrow[-3]=3; boxes[1].narrow[5]=4;
  foreach(boxes[selector].narrow[key]) begin
   if($bits(key)!=16) $fatal(1,"wrong key width %0d",$bits(key));
   if((count==0 && key!=-3)||(count==1 && key!=5)) $fatal(1,"wrong signed key order");
   count++; sum+=boxes[selector].narrow[key];
  end
  if(count!=2 || sum!=7) $fatal(1,"narrow traversal %0d,%0d",count,sum);
  boxes[1].objects[a]=10; boxes[1].objects[b]=20;
  count=0; sum=0;
  foreach(boxes[selector].objects[key]) begin
   seen |= 1 << key.number();
   sum+=boxes[selector].objects[key]; count++;
  end
  if(count!=2 || sum!=30 || seen!=6) $fatal(1,"object traversal");
  $display("PASSED"); $finish(0);
 end
endmodule
