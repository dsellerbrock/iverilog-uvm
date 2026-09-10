class bucket;
 int values[string];
endclass
module main;
 bucket boxes[2];
 int selector=1, count, sum;
 string key="outer";
 initial begin
  boxes[0]=new; boxes[1]=new;
  boxes[0].values["wrong"]=99;
  boxes[1].values["a"]=3; boxes[1].values["b"]=4;
  foreach(boxes[selector].values[key]) begin
   if(key!="a" && key!="b") $fatal(1,"bad shadow key");
   sum+=boxes[1].values[key]; count++;
  end
  if(count!=2 || sum!=7 || key!="outer" || selector!=1) $fatal(1,"shadow traversal");
  $display("PASSED"); $finish(0);
 end
endmodule
