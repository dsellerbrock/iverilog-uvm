module top;
  function int cf2(int a); string s; s = "abc"; return a + s.len(); endfunction
  function int cf3(int a); $display("SYS_TASK_RAN"); return a; endfunction
  localparam int Q = cf2(1); localparam int R = cf3(5);
  initial $display("%s 13.4.3 Q=%0d R=%0d", (Q == 4 && R == 5) ? "PASS" : "FAIL", Q, R);
endmodule
