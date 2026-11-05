class issue2504_data;
  rand bit [7:0] q[$][$];
  constraint values_below_ten { foreach (q[i, j]) q[i][j] < 8'd10; }
endclass

module issue2504_rand_queue_of_queues_foreach;
  issue2504_data data = new;

  initial begin
    data.q = '{'{20, 2}, '{30}};
    if (!data.randomize())
      $fatal(1, "randomize failed");
    if (data.q.size() != 2 || data.q[0].size() != 2
        || data.q[1].size() != 1)
      $fatal(1, "queue dimensions changed");
    if (data.q[0][0] >= 10 || data.q[0][1] >= 10
        || data.q[1][0] >= 10)
      $fatal(1, "foreach constraint not applied");
    $display("q %0d %0d %0d %0d", data.q.size(), data.q[0].size(),
             data.q[1].size(),
             data.q[0][0] < 10 && data.q[0][1] < 10 && data.q[1][0] < 10);
  end
endmodule
