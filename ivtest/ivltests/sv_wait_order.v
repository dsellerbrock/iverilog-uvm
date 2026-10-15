module sv_wait_order;
  event first, second, unrelated, expected, later, same, single;
  event continuation_first, continuation_second, continuation_next;
  event cancel_first, cancel_second;
  event nba_first, nba_second;
  event pre_entry_first, pre_entry_later;
  event persistent_first, persistent_later;

  task automatic automatic_event_order;
    event auto_first, auto_second;
    -> auto_first;
    fork
      begin
        #1;
        -> auto_second;
      end
      begin
        wait_order(auto_first, auto_second)
          $display("automatic-event-pass");
        else $fatal(1, "automatic event order failed");
      end
    join
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
        -> same;
        -> same;
      end
      begin
        wait_order(same, same)
          $display("duplicate-event-pass");
        else $fatal(1, "duplicate event sequence failed");
      end
    join

    -> same;
    wait_order(same, same)
      $fatal(1, "later duplicate used persistent triggered state");
    else $display("duplicate-persistent-later-out-of-order-pass");

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
      automatic_event_order();
      automatic_event_order();
    join

    fork
      begin : cancellable_waiter
        wait_order(cancel_first, cancel_second)
          $fatal(1, "cancelled wait_order succeeded");
        else $fatal(1, "cancelled wait_order failed");
      end
      begin
        #1;
        disable cancellable_waiter;
      end
    join
    -> cancel_first;
    -> cancel_second;

  end
endmodule
