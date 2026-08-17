// Kill generations must be observed independently in every clock domain.
// Epoch-tagged handoffs prevent an old request from reappearing when a
// downstream domain wakes only after Kill and On have both completed.
module sv_assertkill_multiclock_active;
  bit c1, c2, c3;
  bit req2, ack2;
  bit req3, mid3, ack3;
  int failures2, failures3;

  active_two_clock: assert property (
      @(posedge c1) req2 |=> @(posedge c2) ack2)
    else failures2++;

  active_three_clock: assert property (
      @(posedge c1) req3 |=> @(posedge c2) mid3 ##1 @(posedge c3) ack3)
    else failures3++;

  task automatic tick1;
    #1 c1 = 1;
    #1 c1 = 0;
  endtask

  task automatic tick2;
    #1 c2 = 1;
    #1 c2 = 0;
  endtask

  task automatic tick3;
    #1 c3 = 1;
    #1 c3 = 0;
  endtask

  initial begin
    req2 = 1;
    tick1();
    req2 = 0;
    $assertkill(0, sv_assertkill_multiclock_active.active_two_clock);
    $asserton(0, sv_assertkill_multiclock_active.active_two_clock);
    tick2();
    if (failures2 != 0)
      $fatal(1, "Kill retained two-clock request: failures=%0d", failures2);
    req2 = 1;
    tick1();
    req2 = 0;
    tick2();
    if (failures2 != 1)
      $fatal(1, "two-clock checker did not re-arm: failures=%0d", failures2);

    req3 = 1;
    tick1();
    req3 = 0;
    mid3 = 1;
    tick2();
    mid3 = 0;
    $assertkill(0, sv_assertkill_multiclock_active.active_three_clock);
    $asserton(0, sv_assertkill_multiclock_active.active_three_clock);
    tick3();
    if (failures3 != 0)
      $fatal(1, "Kill retained three-clock request: failures=%0d", failures3);
    req3 = 1;
    tick1();
    req3 = 0;
    mid3 = 1;
    tick2();
    mid3 = 0;
    tick3();
    if (failures3 != 1)
      $fatal(1, "three-clock checker did not re-arm: failures=%0d", failures3);

    $display("PASSED");
    $finish;
  end
endmodule
