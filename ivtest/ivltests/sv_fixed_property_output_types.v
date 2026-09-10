// IEEE1800-2017/2023 13.5: assignment conversions during output copy-out.
module sv_fixed_property_output_types;
 class Box;
  int wide[2]; byte narrow[2]; bit [7:0] bits[2]; logic[7:0] four[2]; real rr[2];
 endclass
 function automatic int small_value(output byte value);value=-3;return 0;endfunction
 function automatic int large_value(output int value);value=259;return 0;endfunction
 function automatic int unknowns(output logic[7:0] value);value=8'b10xz0101;return 0;endfunction
 function automatic int realval(output real value);value=2.6;return 0;endfunction
 initial begin
  Box b;int ignored;
  b=new;
  ignored=small_value(b.wide[0]);
  if(b.wide[0]!=-3)$fatal(1,"signed widening");
  ignored=large_value(b.narrow[0]);
  if(b.narrow[0]!=3)$fatal(1,"narrowing");
  ignored=unknowns(b.bits[0]);
  if(b.bits[0]!==8'b10000101)$fatal(1,"two-state conversion");
  ignored=unknowns(b.four[0]);
  if(b.four[0]!==8'b10xz0101)$fatal(1,"four-state preservation");
  ignored=realval(b.wide[1]);
  if(b.wide[1]!=3)$fatal(1,"real to integer");
  ignored=large_value(b.rr[0]);
  if(b.rr[0]!=259.0)$fatal(1,"integer to real");
  $display("PASSED");
 end
endmodule
