module sv_automatic_integral_default_recursive;
 integer completed=0;
 task automatic watch(input integer depth);
  bit [3:0] value;
  time origin;
  origin=$time;
  fork
   begin @(negedge value[0]);if($time-origin!=3)$fatal(1,"recursive default history");end
   begin #1;value[2:1]=0;#1;value[0]=1;#1;value[0]=0;end
   begin if(depth)begin #1;watch(depth-1);end end
  join
  completed++;
 endtask
 initial begin repeat(3)watch(2);if(completed!=9)$fatal(1,"missing recursive frame");$display("PASSED");$finish(0);end
 initial begin #100;$fatal(1,"recursive wait hung");end
endmodule
