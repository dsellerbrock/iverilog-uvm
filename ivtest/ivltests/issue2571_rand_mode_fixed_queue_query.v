class issue2571_item;
  rand bit [3:0] q[2][$];
endclass

module issue2571_rand_mode_fixed_queue_query;
  initial begin
    issue2571_item item;
    item = new;
    item.q[0] = '{1, 2};
    item.q[1] = '{3};

    if (item.q[0][0].rand_mode() !== 1)
      $fatal(1, "new queue element should start active");
    item.q[0][0].rand_mode(0);
    if (item.q[0][0].rand_mode() !== 0
        || item.q[0][1].rand_mode() !== 1
        || item.q[1][0].rand_mode() !== 1)
      $fatal(1, "queue element query returned the wrong mode");
    item.q[0][0].rand_mode(1);
    if (item.q[0][0].rand_mode() !== 1)
      $fatal(1, "queue element mode did not re-enable");

    $display("PASSED");
  end
endmodule
