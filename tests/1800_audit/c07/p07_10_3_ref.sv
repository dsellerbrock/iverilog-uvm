module p07_10_3_ref;
  int q[$];
  task automatic t(ref int r); #1 r = 99; endtask
  function automatic string s(); string x = ""; foreach (q[i]) x = {x, $sformatf("%0d ", q[i])}; return x; endfunction
  initial begin
    q = '{2,4,8}; fork t(q[1]); join_none #0 q.push_front(1); #2 $display("R1 %s", s()); // 1 2 99 8
    q = '{2,4,8}; fork t(q[1]); join_none #0 void'(q.pop_front()); #2 $display("R2 %s", s()); // 99 8
    q = '{2,4,8}; fork t(q[1]); join_none #0 q.insert(0, 7); #2 $display("R3 %s", s()); // 7 2 99 8
    q = '{2,4,8}; fork t(q[1]); join_none #0 q.delete(1); #2 $display("R4 %s", s()); // 2 8
    q = '{2,4,8}; fork t(q[1]); join_none #0 q = {q, 6}; #2 $display("R5 %s", s()); // 2 4 8 6
  end
endmodule
