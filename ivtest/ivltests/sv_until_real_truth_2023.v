module until_real_truth;
bit clk=0, fire=0; real p=0.5, q=0.0; int fails=0;
always #5 clk=~clk;
assert property (@(posedge clk) fire |=> p until q) else fails++;
initial begin
#10 fire=1; #10 fire=0; #20 q=0.5; #10;
if(fails) $fatal(1,"real Boolean truth");
$display("PASS real until truth"); $finish(0);
end
endmodule
