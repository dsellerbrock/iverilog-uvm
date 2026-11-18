// IEEE 1800-2017/2023 16.12.18 and 9.4.2.1.
module issue3658_property_event_or;
  logic c1 = 0, c2 = 0, enabled = 1;
  event pulse;
  always #5 c1 = ~c1;
  always #7 c2 = ~c2;
  initial begin
    #9 enabled = 0;
    #13 enabled = 1;
  end
  initial begin
    #12 -> pulse;
    #6 -> pulse;
  end

  int positional_count = 0, named_count = 0, default_count = 0;
  bit [63:0] positional_times = 0, named_times = 0, default_times = 0;

  function automatic bit [63:0] at(time tick);
    return 64'd1 << tick;
  endfunction

  property p(event ev, logic value);
    @(ev) value;
  endproperty

  property q(event ev = negedge c1 or posedge c2);
    @(ev) 1'b1;
  endproperty

  positional: assert property (p(posedge c1 or posedge c2, 1'b1)) begin
    positional_count++;
    positional_times |= at($time);
  end else $fatal(1, "positional event property failed");

  named: assert property (p(.ev((negedge c1 iff enabled) or (posedge c2 or pulse)),
                            .value(1'b1))) begin
    named_count++;
    named_times |= at($time);
  end else $fatal(1, "named event property failed");

  defaulted: assert property (q(.ev())) begin
    default_count++;
    default_times |= at($time);
  end else $fatal(1, "defaulted event property failed");

  initial begin
    #39;
    // The two posedges at time 35 produce one assertion attempt.
    if (positional_count != 6 ||
        positional_times !== (at(5) | at(7) | at(15) | at(21) | at(25) | at(35)))
      $fatal(1, "positional actual: count=%0d ticks=%h", positional_count, positional_times);
    if (named_count != 6 ||
        named_times !== (at(7) | at(12) | at(18) | at(21) | at(30) | at(35)))
      $fatal(1, "named actual: count=%0d ticks=%h", named_count, named_times);
    if (default_count != 6 ||
        default_times !== (at(7) | at(10) | at(20) | at(21) | at(30) | at(35)))
      $fatal(1, "default actual: count=%0d ticks=%h", default_count, default_times);
    $display("PASSED");
    $finish(0);
  end
endmodule
