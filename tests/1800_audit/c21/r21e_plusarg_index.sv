module r21e_index;
logic [8*32:1] tn;
integer r;
initial begin
 r=$value$plusargs("TESTNAME=%s",tn);
 $display("RESULT rc=%0d value=%s selected=%s selected_ok=%0d",r,tn,tn[16:1],tn[16:1]=="t1");
end
endmodule
