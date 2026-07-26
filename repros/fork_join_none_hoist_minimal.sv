module top;
  int a=-1, b=-1;
  task automatic noargs();               int loc=0; loc++; loc++; loc++; a = loc; endtask
  task automatic withport(output int o); int loc=0; loc++; loc++; loc++; o = loc; endtask
  initial begin
    fork noargs(); join_none
    fork withport(b); join_none
    #2;
    $display("noargs=%0d withport=%0d (want 3 3)", a, b);
    $finish(0);
  end
endmodule
