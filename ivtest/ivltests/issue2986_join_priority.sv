module issue2986_join_priority;
  int order, z, o, short_first, long_first, mid_first, default_first;
  initial begin
    repeat (1000) begin
      order=0;
      randsequence (main)
        main: rand join (0.0) s1 s2;
        s1: a b; s2: c d;
        a: {order=order*10+1;}; b: {order=order*10+2;};
        c: {order=order*10+3;}; d: {order=order*10+4;};
      endsequence
      if (!(order inside {1234,1324,1342,3124,3142,3412})) $fatal(1,"invalid order");
      if (order==1234 || order==3412) z++;
      order=0;
      randsequence (main)
        main: rand join (1.0) s1 s2;
        s1: a b; s2: c d;
        a: {order=order*10+1;}; b: {order=order*10+2;};
        c: {order=order*10+3;}; d: {order=order*10+4;};
      endsequence
      if (!(order inside {1234,1324,1342,3124,3142,3412})) $fatal(1,"invalid order");
      if (order==1234 || order==3412) o++;
    end
    repeat (1000) begin
      order=0;
      randsequence (main)
        main: rand join (0.0) short_lane long_lane;
        short_lane: a; long_lane: b c d;
        a: {order=order*10+1;}; b: {order=order*10+2;};
        c: {order=order*10+3;}; d: {order=order*10+4;};
      endsequence
      if (!(order inside {1234,2134,2314,2341})) $fatal(1,"invalid short priority order");
      if (order==1234) short_first++;
      order=0;
      randsequence (main)
        main: rand join (1.0) short_lane long_lane;
        short_lane: a; long_lane: b c d;
        a: {order=order*10+1;}; b: {order=order*10+2;};
        c: {order=order*10+3;}; d: {order=order*10+4;};
      endsequence
      if (!(order inside {1234,2134,2314,2341})) $fatal(1,"invalid long priority order");
      if (order==1234) long_first++;
    end
    if (short_first <= long_first + 100) $fatal(1,"unequal lane priority reversed");
    if (z<=o+80) $fatal(1,"priority reversed");
    repeat (1000) begin
      order=0;
      randsequence (main)
        main: rand join (0.5) short_lane long_lane;
        short_lane: a; long_lane: b c d;
        a: {order=order*10+1;}; b: {order=order*10+2;};
        c: {order=order*10+3;}; d: {order=order*10+4;};
      endsequence
      if (!(order inside {1234,2134,2314,2341})) $fatal(1,"invalid midpoint order");
      if (order==1234) mid_first++;
      order=0;
      randsequence (main)
        main: rand join short_lane long_lane;
        short_lane: a; long_lane: b c d;
        a: {order=order*10+1;}; b: {order=order*10+2;};
        c: {order=order*10+3;}; d: {order=order*10+4;};
      endsequence
      if (!(order inside {1234,2134,2314,2341})) $fatal(1,"invalid default order");
      if (order==1234) default_first++;
    end
    if (mid_first < 400 || mid_first > 600 ||
        default_first < 400 || default_first > 600)
      $fatal(1,"midpoint/default must not prioritize length");
    $display("PASS join priority");
  end
endmodule
