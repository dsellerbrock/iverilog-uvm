module top;
  class endpoint;
    rand bit [2:0] value;
    constraint finite_domain { value inside {3'd0, 3'd2, 3'd5}; }
  endclass

  class pair;
    rand endpoint left;
    rand endpoint right;
    constraint ordered_pair { left.value < right.value; }
  endclass

  pair item;
  int unsigned seed = 20261004;
  int unsigned pair_02, pair_05, pair_25;
  int unsigned i;

  initial begin
    automatic process self_p = process::self();
    item = new;
    item.left = new;
    item.right = new;
    pair_02 = 0;
    pair_05 = 0;
    pair_25 = 0;
    self_p.srandom(seed);

    for (i = 0; i < 64; i++) begin
      if (!item.randomize())
        $fatal(1, "joint class-graph randomize failed at draw %0d", i);
      case ({item.left.value, item.right.value})
        {3'd0, 3'd2}: pair_02++;
        {3'd0, 3'd5}: pair_05++;
        {3'd2, 3'd5}: pair_25++;
        default: $fatal(1, "illegal tuple (%0d,%0d)",
                        item.left.value, item.right.value);
      endcase
    end
    if (!pair_02 || !pair_05 || !pair_25)
      $fatal(1, "fixed seed did not exercise every legal tuple");
    $display("PASS vvp_joint_randomize seed=%0d draws=%0d tuples={(0,2):%0d,(0,5):%0d,(2,5):%0d}",
             seed, i, pair_02, pair_05, pair_25);
    $finish;
  end
endmodule
