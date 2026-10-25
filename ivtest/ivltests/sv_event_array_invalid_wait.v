module sv_event_array_invalid_wait;
  event events[0:0];
  bit invalid_hit;
  bit valid_hit;
  int index;

  initial begin
    index = 9;
    fork
      @events[index] invalid_hit = 1'b1;
      @events[0] valid_hit = 1'b1;
    join_none

    #1;
    if (invalid_hit)
      $fatal(1, "invalid event-array wait resumed");
    if (valid_hit)
      $fatal(1, "valid event-array wait resumed before trigger");

    -> events[0];
    #1;
    if (!valid_hit)
      $fatal(1, "valid event-array wait did not resume");
    if (invalid_hit)
      $fatal(1, "invalid event-array wait resumed after valid trigger");

    $display("PASS");
  end
endmodule
