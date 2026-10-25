module p06_23b;
  int pass=0, fail=0;
  task automatic ck(input string s, input bit c); if(c) pass++; else begin fail++; $display("FAIL %s",s); end endtask
  typedef bit node;
  typedef bit signed [7:0] BYTE; typedef byte signed MY_CHAR; typedef bit signed [0:7] ETYB;
  bit [12:0] A_bus, B_bus;
  initial begin
    ck("same", type(A_bus)==type(B_bus));
    ck("alias", type(node)==type(bit) && type(MY_CHAR)==type(byte));
    ck("predefined", type(BYTE)==type(byte) && type(int)==type(bit signed [31:0]));
    ck("range_direction", type(ETYB)!=type(byte));
    ck("builtin_distinct", type(int)!=type(shortint) && type(logic[3:0])!=type(bit[3:0]));
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
