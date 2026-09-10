class bucket;
 int values[string];
 int grid[2][3];
endclass
module main;
 bucket boxes[];
 int done;
 task automatic visit(input int which);
  int sum, count, columns;
  foreach(boxes[which].values[key]) begin
   #1;
   sum+=boxes[which].values[key]; count++;
  end
  foreach(boxes[which].grid[,column]) begin
   if($bits(column)!=32 || column<0 || column>2) $fatal(1,"bad fixed index");
   columns++;
  end
  if(count!=2 || sum!=(which ? 7 : 30) || columns!=3) $fatal(1,"activation traversal");
  done++;
 endtask
 initial begin
  boxes=new[2]; boxes[0]=new; boxes[1]=new;
  boxes[0].values["x"]=10; boxes[0].values["y"]=20;
  boxes[1].values["a"]=3; boxes[1].values["b"]=4;
  repeat(3) begin fork visit(0); visit(1); join end
  if(done!=6) $fatal(1,"missing checks");
  $display("PASSED"); $finish(0);
 end
 initial begin #100; $fatal(1,"timeout"); end
endmodule
