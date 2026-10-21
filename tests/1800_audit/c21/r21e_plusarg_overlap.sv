module r21e;
logic [8*32:1] value;
integer rc;
initial begin
 rc=$value$plusargs("TESTNAME=%s",value);
 $display("RESULT rc=%0d value=%s raw=%h",rc,value,value);
end
endmodule
