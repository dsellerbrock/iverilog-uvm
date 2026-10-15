module sv_wait_order;
  event first, second, unrelated, expected, later, same, single;
  event cancel_first, cancel_second;
  event nba_first, nba_second;
  event pre_entry_first, pre_entry_later;
  event persistent_first, persistent_later;
  integer duplicate_completed = 0;

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
    fork
      begin
        #1;
        if (duplicate_completed)
          $fatal(1, "repeated event used persistent state twice");
        -> same;
      end
      begin
        wait_order(same, same) begin
          duplicate_completed = 1;
          $display("repeated-persistent-event-pass");
        end
        else $fatal(1, "repeated persistent event order failed");
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
