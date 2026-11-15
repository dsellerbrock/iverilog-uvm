// IEEE 1800-2023 9.4.2: an event control on an expression that uses a
// built-in method of an aggregate (da.size() > 0) is reevaluated when the
// size changes, like @(da.size()).
module issue2843_size_relational_event;
  int da[];
  int q[$];
  initial begin
    fork
      begin @(da.size() > 0); $display("%0t da woke %0d", $time, da.size()); end
      begin @(q.size() == 2); $display("%0t q woke %0d", $time, q.size()); end
      begin @(da.size()); $display("%0t bare woke %0d", $time, da.size()); end
    join_none
    #1 da = new[2];
    #1 q.push_back(1);
    #1 q.push_back(2);
    #1 $finish;
  end
endmodule
