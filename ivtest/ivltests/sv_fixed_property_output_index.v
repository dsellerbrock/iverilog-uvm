// IEEE1800-2017/2023 13.5: typed indexed actuals are copied on return.
module sv_fixed_property_output_index;
 class Item; int value; endclass
 class Box;
  int slots[3:2]; real reals[2:3]; string names[2]; Item objects[2];
  int grid[2:3][5:4];
 endclass
 class Env; Box box; endclass
 int calls=0, index_calls=0;
 Env env;
 function automatic int index_value(); index_calls++; return 2; endfunction
 function automatic int produce(output int value); calls++; value=37; return 0; endfunction
 function automatic int typed(output real r,output string s,output Item obj);
  r=2.5;s="copied";obj=new;obj.value=41;return 0;
 endfunction
 function automatic int modify(inout int value);value+=5;return 0;endfunction
 initial begin
  int ignored;
  env=new;env.box=new;
  env.box.slots[3]=-1;env.box.slots[2]=10;
  ignored=produce(env.box.slots[index_value()]);
  if(calls!=1 || index_calls!=1 ||
     env.box.slots[3]!=-1 || env.box.slots[2]!=37)$fatal(1,"receiver/index");
  ignored=modify(env.box.slots[2]);
  if(env.box.slots[2]!=42)$fatal(1,"inout");
  ignored=typed(env.box.reals[3],env.box.names[1],env.box.objects[1]);
  if(env.box.reals[3]!=2.5 || env.box.names[1]!="copied" ||
     env.box.objects[1]==null || env.box.objects[1].value!=41)$fatal(1,"typed property");
  env.box.grid[2][5]=-1; env.box.grid[3][4]=-1;
  ignored=produce(env.box.grid[3][4]);
  if(env.box.grid[2][5]!=-1 || env.box.grid[3][4]!=37)$fatal(1,"multidimensional");
  $display("PASSED");
 end
endmodule
