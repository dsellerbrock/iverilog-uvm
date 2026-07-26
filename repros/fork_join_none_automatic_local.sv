module top;
  int a=-1;
  task automatic t4();
    int loc = 0;
    loc++; loc++; loc++;
    $display("  inside t4: loc=%0d", loc);
    a = loc;
  endtask
  initial begin
    fork t4(); join_none
    #1;
    $display("after fork: a=%0d (want 3)", a);
    t4();
    $display("after direct call: a=%0d (want 3)", a);
    $finish(0);
  end
endmodule
