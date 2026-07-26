module top;
  int a=-1, b=-1;
  task automatic noargs();                 // zero ports
    int loc = 0;
    loc++; loc++; loc++;
    a = loc;
  endtask
  task automatic onearg(input int dummy);  // one port
    int loc = 0;
    loc++; loc++; loc++;
    b = loc;
  endtask
  initial begin
    fork noargs(); join_none
    fork onearg(0); join_none
    #2;
    $display("zero-port task under fork/join_none : %0d (want 3)", a);
    $display("one-port task under fork/join_none  : %0d (want 3)", b);
    a = -1; b = -1;
    noargs(); onearg(0);
    $display("same two called directly            : %0d %0d (want 3 3)", a, b);
    $finish(0);
  end
endmodule
