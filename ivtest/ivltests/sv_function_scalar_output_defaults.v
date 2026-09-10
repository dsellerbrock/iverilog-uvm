// IEEE1800-2017/2023 13.4.2,13.5: formal output lifetime and defaults.
module sv_function_scalar_output_defaults;
 class Box;int value;endclass
 function automatic int automatic_values(output logic[39:0] four,output bit[7:0] two,
   output real r,output string s,output Box b);
  if(four!==40'bx || two!==0 || r!=0.0 || s!="" || b!=null)
   $fatal(1,"automatic output defaults");
  four=40'h123456789a;two=8'h81;r=2.5;s="copied";b=new;b.value=37;return 0;
 endfunction
 function int static_values(input int iteration,output int value,output string text);
  if(value!=iteration*7 || (iteration==0 && text!="") ||
     (iteration!=0 && text!="retained"))$fatal(1,"static output retention");
  value+=7;text="retained";return 0;
 endfunction
 initial begin
  logic[39:0] four;bit[7:0] two;real r;string s;Box b;
  int ignored,value;string text;
  repeat(3)begin
   four=0;two=255;r=19;s="caller";b=new;
   ignored=automatic_values(four,two,r,s,b);
   if(four!==40'h123456789a || two!==8'h81 || r!=2.5 || s!="copied" ||
      b==null || b.value!=37)$fatal(1,"automatic outputs");
  end
  for(int i=0;i<3;i++)begin
   value=99;text="caller";ignored=static_values(i,value,text);
   if(value!=(i+1)*7 || text!="retained")$fatal(1,"static outputs");
  end
  $display("PASSED");
 end
endmodule
