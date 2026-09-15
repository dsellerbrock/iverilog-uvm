module sv_const_string_putc;
 function automatic string folded();
  string s="ABC";integer index=1,character="Z";
  s.putc(index++,character++);
  if(index!=2||character!=("Z"+1))return "SIDE_EFFECT_ERROR";
  s.putc(-1,"X");s.putc(99,"Y");s.putc(0,0);
  s.putc(64'h1_0000_0000,"Q");
  s.putc(2,"D");s.putc(2,"C");
  return s;
 endfunction
 function automatic string direct_result();direct_result="ABC";direct_result.putc(1,"Z");endfunction
 function automatic string boundaries();string s;s.putc(0,"A");if(s!="")return "EMPTY_ERROR";s="ABC";s.putc(1,16'h15a);s.putc(1.6,65.6);return s;endfunction
 localparam string FOLDED=folded(),DIRECT=direct_result(),BOUNDARIES=boundaries();
 initial begin
  string runtime_value;runtime_value=folded();
  if(FOLDED!="QZC"||DIRECT!="AZC"||BOUNDARIES!="AZB")$fatal(1,"constant putc %s %s %s",FOLDED,DIRECT,BOUNDARIES);
  if(runtime_value!=FOLDED)$fatal(1,"constant/runtime mismatch %s %s",FOLDED,runtime_value);
  $display("PASSED");
 end
endmodule
