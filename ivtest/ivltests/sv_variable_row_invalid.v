module main;
 logic [7:0] a[2][2];
 logic [7:0] b[2][2];
 integer idx;
 initial begin
  a[0]='{8'h11,8'h12};a[1]='{8'h21,8'h22};b[0]='{8'h31,8'h32};
  a['x]=b[0];a[-1]<=b[0];a['z]<='{default:0};#1;
  if(a[0][0]!==8'h11 || a[0][1]!==8'h12 || a[1][0]!==8'h21 || a[1][1]!==8'h22)
    $fatal(1,"static invalid destination wrote row");
  idx=0;a[idx]=b['x];
  if(a[0][0]!==8'hxx || a[0][1]!==8'hxx) $fatal(1,"invalid source default");
  $display("PASSED");
 end
endmodule
