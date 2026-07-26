module top;
  int a=-1, b=-1, c=-1, d=-1;
  task automatic t(output int o);
    int loc = 0;
    loc++; loc++; loc++;
    o = loc;
  endtask
  class K;
    task automatic m(output int o); int loc=0; loc++; loc++; loc++; o = loc; endtask
  endclass
  K k;
  initial begin
    k = new();
    fork t(a); join_none                              // task call as the fork body
    fork begin int loc=0; loc++; loc++; loc++; b=loc; end join_none  // inline block
    fork k.m(c); join_none                            // class method as the fork body
    fork begin t(d); end join_none                    // task call WRAPPED in a block
    #2;
    $display("fork <task>       : %0d (want 3)", a);
    $display("fork begin..end   : %0d (want 3)", b);
    $display("fork <method>     : %0d (want 3)", c);
    $display("fork begin <task> : %0d (want 3)", d);
    $finish(0);
  end
endmodule
