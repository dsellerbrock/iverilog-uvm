class holder;
 logic [7:0] four[0:1]; bit [7:0] two[0:1];
endclass
module sv_class_array_packed_incdec_bounds;
 holder object; logic [63:0] ub; logic signed [63:0] sb; integer word; int calls;
 logic [3:0] result; bit [3:0] two_result;
 function automatic int base(); calls++; return 4; endfunction
 initial begin
  object=new; object.four='{8'haa,8'h55}; object.two='{8'haa,8'h55};
  ub='1; result=object.four[0][ub+:4]++;
  if(result!==4'bxxxx || object.four[0]!==8'haa) $fatal(1,"unsigned allones alias");
  sb=-2; result=object.four[0][sb+:4]--;
  if(result!==4'b10xx || object.four[0]!==8'b101010xx) $fatal(1,"signed overlap");
  word='x; calls=0; result=object.four[word][base()+:4]++;
  if(result!==4'bxxxx || calls!=1 || object.four[1]!==8'h55) $fatal(1,"invalidword still evaluates packedbase");
  calls=0; two_result=++object.two[word][base()+:4];
  if(two_result!==1 || calls!=1 || object.two[0]!==8'haa || object.two[1]!==8'h55) $fatal(1,"invalid two-state word carrier width");
  $display("PASSED");
 end
endmodule
