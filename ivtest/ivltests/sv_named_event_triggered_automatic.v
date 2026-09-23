`timescale 1ns/1ps
class named_event_triggered_worker;
  virtual task run(input int id, input int first_at);
    event e;
    bit first_rearmed = 0;
    bit reset_rearmed = 0;
    bit cancelled_woke = 0;
    int changes = 0;

    fork : cancelled_wait
      begin
        @(e.triggered);
        cancelled_woke = 1;
      end
    join_none
    #0 disable cancelled_wait;

    fork
      begin
        @(e.triggered);
        changes++;
        if ($time != first_at || !e.triggered)
          $fatal(1, "activation %0d first rise t=%0t", id, $time);
        first_rearmed = 1;
        @(e.triggered);
        changes++;
        if ($time != first_at + 1 || e.triggered)
          $fatal(1, "activation %0d reset t=%0t", id, $time);
        reset_rearmed = 1;
        @(e.triggered);
        changes++;
        if ($time != first_at + 1 || !e.triggered)
          $fatal(1, "activation %0d second rise t=%0t", id, $time);
      end
      begin
        #first_at -> e;
        wait (first_rearmed);
        #0 -> e;
        #1;
        wait (reset_rearmed);
        #0 -> e;
      end
    join
    if (changes != 3 || cancelled_woke)
      $fatal(1, "activation %0d changes=%0d cancelled=%0b",
             id, changes, cancelled_woke);
  endtask
endclass

module sv_named_event_triggered_automatic;
  named_event_triggered_worker worker;
  initial begin
    worker = new;
    fork
      worker.run(1, 1);
      worker.run(2, 2);
    join
    $display("PASS automatic @(e.triggered): isolated activations, stable slot, reset, cancellation");
    $finish(0);
  end
  initial begin
    #8 $fatal(1, "automatic triggered-property watchdog");
  end
endmodule
