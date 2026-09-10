class bucket;
 int values[string];
endclass
module main;
 bucket boxes[2];
 int selector=1, count=0, sum=0;
 initial begin
  boxes[0]=new; boxes[1]=new;
  boxes[0].values["wrong"]=99;
  boxes[1].values["a"]=3; boxes[1].values["b"]=4;
  foreach(boxes[selector].values[key]) begin
   if (key != "a" && key != "b") $fatal(1,"bad key");
   if ((count==0 && key!="a") || (count==1 && key!="b")) $fatal(1,"string key order");
   sum+=boxes[selector].values[key]; count++;
  end
  if(count!=2 || sum!=7 || selector!=1) $fatal(1,"bad selected associative loop");
  $display("PASSED"); $finish(0);
 end
endmodule
