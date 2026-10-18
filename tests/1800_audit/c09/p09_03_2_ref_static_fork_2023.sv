module top;
  int s;
  task automatic t(ref static int x);
    fork x = 5; join_none
  endtask
  initial begin
    t(s);
    #1 $display("%s 9.3.2.ref_static_in_fork_none s=%0d", s == 5 ? "PASS" : "FAIL", s);
  end
endmodule
