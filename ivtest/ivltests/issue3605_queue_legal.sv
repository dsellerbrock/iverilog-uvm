module issue3605_queue_legal;
  int q[$];
  int fixed_array[2];
  initial begin
    q.push_back(1);
    q[0] = 7;
    fixed_array[0] <= 9;
    #1;
    if (q[0] !== 7 || fixed_array[0] !== 9) $fatal(1, "incorrect assignment");
    $display("PASS");
  end
endmodule
