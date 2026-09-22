module empty_or;
bit clk=0, a=1,b=1,c=1; int left_f=0,right_f=0;
always #5 clk=~clk;
assert property (@(posedge clk) (a[*0] ##0 b) or c) else left_f++;
assert property (@(posedge clk) (b ##0 a[*0]) or c) else right_f++;
initial begin #10 c=0; #10 c=1; #10;
if(left_f!=1 || right_f!=1) $fatal(1,"empty OR failures %0d/%0d",left_f,right_f);
$display("PASS empty OR"); $finish(0); end
endmodule
