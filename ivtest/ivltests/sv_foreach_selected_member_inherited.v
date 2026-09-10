class base #(type K=string);
 int values[K];
endclass
class derived extends base #(string);
endclass
class holder;
 derived boxes[2];
endclass
module main;
 holder env;
 int selector=1, count, sum;
 initial begin
  env=new; env.boxes[0]=new; env.boxes[1]=new;
  env.boxes[0].values["wrong"]=99;
  env.boxes[1].values["a"]=3; env.boxes[1].values["b"]=4;
  foreach(env.boxes[(selector+0)].values[key]) begin
   if(key!="a" && key!="b") $fatal(1,"wrong inherited key");
   sum+=env.boxes[selector].values[key]; count++;
  end
  if(count!=2 || sum!=7) $fatal(1,"inherited traversal");
  $display("PASSED"); $finish(0);
 end
endmodule
