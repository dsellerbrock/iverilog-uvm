module sv_wait_order;
  event first, second, unrelated, expected, later, single;
  event continuation_first, continuation_second, continuation_next;
  event cancel_first, cancel_second;
  event mixed_first, mixed_second;
  event nba_first, nba_second;
  event pre_entry_first, pre_entry_later;
  event persistent_first, persistent_later;
  bit mixed_early_success, mixed_late_success;
  integer cancel_completed = 0;

  task automatic automatic_event_order(input bit fail_order,
                                       input integer delay_before);
    event auto_first, auto_second, auto_later;
    -> auto_first;
    fork
      begin
        #(delay_before);
        if (fail_order) begin
          -> auto_later;
        end else begin
          -> auto_second;
          #1;
          -> auto_later;
        end
      end
      begin
        wait_order(auto_first, auto_second, auto_later) begin
          if (fail_order)
            $fatal(1, "automatic out-of-order wait succeeded");
          $display("automatic-event-pass");
        end else begin
          if (!fail_order)
            $fatal(1, "automatic event order failed");
          $display("automatic-event-out-of-order-pass");
        end
      end
    join
  endtask

  task automatic mixed_event_order(output bit success);
    wait_order(mixed_first, mixed_second)
      success = 1'b1;
    else
      success = 1'b0;
  endtask

  task automatic cancelled_event_order;
    wait_order(cancel_first, cancel_second)
      cancel_completed++;
    else $fatal(1, "cancelled wait_order failed");
  endtask

  initial begin
    fork
      begin
        #1;
        -> first;
        -> first;
        -> unrelated;
        -> second;
      end
      begin
        wait_order(first, second)
          $display("same-slot-repeat-pass");
        else $fatal(1, "same-slot order failed");
      end
    join

    fork
      begin
        wait_order(continuation_first, continuation_second)
          -> continuation_next;
        else $fatal(1, "first parallel wait_order failed");
      end
      begin
        wait_order(continuation_first, continuation_second, continuation_next)
          $display("parallel-waiter-state-before-resume-pass");
        else $fatal(1, "second parallel wait_order failed");
      end
      begin
        #1;
        -> continuation_first;
        -> continuation_second;
      end
    join

    // A later event cannot use persistent triggered state.
    -> pre_entry_later;
    fork
      begin
        #1;
        -> pre_entry_first;
        -> pre_entry_later;
      end
      begin
        wait_order(pre_entry_first, pre_entry_later)
          $fatal(1, "pre-entry later event satisfied wait_order");
        else $display("pre-entry-later-out-of-order-pass");
      end
    join

    -> pre_entry_first;
    -> pre_entry_later;
    fork
      begin
        #1;
        -> pre_entry_first;
        -> pre_entry_later;
      end
      begin
        wait_order(pre_entry_first, pre_entry_later)
          $fatal(1, "pre-entry later event satisfied persistent first wait_order");
        else $display("pre-entry-later-with-first-out-of-order-pass");
      end
    join

    fork
      begin
        #1;
        -> later;
        -> expected;
      end
      begin
        wait_order(expected, later)
          $fatal(1, "out-of-order wait succeeded");
        else begin : wait_order_failed
          integer failure_code;
          failure_code = 1;
          if (failure_code)
            $display("out-of-order-else-pass");
        end
      end
    join

    -> single;
    wait_order(single)
      $display("single-event-triggered-pass");
    else $fatal(1, "single triggered event failed");
    -> persistent_first;
    fork
      begin
        #1;
        -> persistent_later;
      end
      begin
        wait_order(persistent_first, persistent_later)
          $display("first-trigger-persistent-pass");
        else $fatal(1, "persistent first event failed");
      end
    join

    fork
      begin
        #1;
        ->> nba_first;
        ->> nba_second;
      end
      begin
        wait_order(nba_first, nba_second)
          $display("nonblocking-trigger-pass");
        else $fatal(1, "nonblocking event order failed");
      end
    join

    fork
      automatic_event_order(1'b1, 1);
      automatic_event_order(1'b0, 2);
    join

    fork
      begin
        mixed_event_order(mixed_early_success);
      end
      begin
        #1;
        -> mixed_first;
        #1;
        fork
          mixed_event_order(mixed_late_success);
          begin
            #1;
            -> mixed_second;
          end
        join
      end
    join
    if (mixed_early_success !== 1'b1 || mixed_late_success !== 1'b0)
      $fatal(1, "shared trigger outcomes early=%b late=%b",
             mixed_early_success, mixed_late_success);
    $display("shared-trigger-mixed-outcomes-pass");

    fork
      begin : cancellable_waiter
        cancelled_event_order();
      end
      begin
        #1;
        -> cancel_first;
        #1;
        disable cancellable_waiter;
      end
    join
    if (cancel_completed != 0)
      $fatal(1, "cancelled wait_order completed");
    #1;
    fork
      cancelled_event_order();
      begin
        #1;
        -> cancel_first;
        #1;
        -> cancel_second;
      end
    join
    if (cancel_completed != 1)
      $fatal(1, "restarted wait_order completion count=%0d", cancel_completed);
    $display("cancel-after-first-restart-pass");

  end
endmodule
