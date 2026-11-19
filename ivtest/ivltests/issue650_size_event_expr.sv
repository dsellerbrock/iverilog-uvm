module top;
  real a[];
  int b[];
  int q[$];
  typedef int queue_t[$];
  queue_t bank[2];
  logic lo = 1'bx;
  bit enabled;
  event named_event;
  int pos_count, neg_count, edge_count, relational_count;
  int queue_count, list_count, mixed_count, guarded_count, indexed_count;
  int receiver_count;
  int recipe_count, recipe_count_at_wake;
  int words[4];

  always @(posedge a.size()) begin
    if ($time != 2 && $time != 9)
      $fatal(1, "unexpected size posedge at %0t", $time);
    pos_count++;
  end

  always @(negedge a.size()) begin
    if ($time != 5)
      $fatal(1, "unexpected size negedge at %0t", $time);
    neg_count++;
  end

  always @(edge {a.size(), lo}) begin
    if ($time != 5 && $time != 6 && $time != 7)
      $fatal(1, "unexpected edge on concatenation at %0t", $time);
    edge_count++;
  end

  always @({1'b0, a.size()} > 0) begin
    if ($time != 1 && $time != 6 && $time != 9)
      $fatal(1, "unexpected change of size predicate at %0t", $time);
    relational_count++;
  end

  always @(posedge q.size()) begin
    if ($time != 7)
      $fatal(1, "unexpected queue size posedge at %0t", $time);
    queue_count++;
  end

  always @(b.size() or posedge a.size()) begin
    if ($time != 2 && $time != 3 && $time != 9)
      $fatal(1, "unexpected event-list wake at %0t", $time);
    list_count++;
  end

  function automatic int observe_size(input int size);
    recipe_count++;
    return size;
  endfunction

  initial begin
    #2;
    @(observe_size(a.size()) > 0, named_event);
    if ($time != 4 || recipe_count == 0)
      $fatal(1, "mixed wait did not select the named event at time 4");
    recipe_count_at_wake = recipe_count;
    mixed_count++;
  end

  initial begin
    @(posedge a.size() iff enabled);
    if ($time != 9)
      $fatal(1, "guard admitted a size edge at %0t", $time);
    guarded_count++;
  end

  initial begin
    words[0] = 30;
    words[1] = 20;
    words[2] = 30;
    words[3] = 30;
    #1;
    // Sizes 0, 2 and 3 select words with equal values. The unselected
    // write also stays quiet until the size selects the changed word.
    @(words[a.size()]);
    if ($time != 5)
      $fatal(1, "unexpected indexed expression wake at %0t", $time);
    indexed_count++;
  end

  initial begin
    bank[0] = {11};
    bank[1] = {21, 22};
    #1;
    @(bank[b.size() != 0].size());
    if ($time != 3)
      $fatal(1, "unexpected change of indexed queue size at %0t", $time);
    receiver_count++;
    @(posedge bank[b.size() != 0].size());
    if ($time != 4)
      $fatal(1, "unexpected indexed queue size posedge at %0t", $time);
    receiver_count++;
  end

  initial begin
    #1 a = new[2];
    #1 a = new[3];
    #1 begin
      a[0] = 1.0;
      words[1] = 21;
      b = new[4];
      lo = 1'bz;
      enabled = 1;
    end
    #1 begin
      a = new[3](a);
      bank[1].push_back(23);
      lo = 1'bx;
      -> named_event;
    end
    #1 begin
      words[2] = 40;
      a = new[2](a);
      lo = 1'b1;
    end
    #1 begin
      a.delete();
      lo = 1'b0;
    end
    #1 begin
      q.push_back(17);
      lo = 1'bz;
    end
    #1 begin
      q.push_back(23);
      lo = 1'bx;
    end
    #1 a = new[1];
    #1;
    if (pos_count != 2 || neg_count != 1 || edge_count != 3
        || relational_count != 3 || queue_count != 1 || list_count != 3
        || mixed_count != 1 || guarded_count != 1 || indexed_count != 1
        || receiver_count != 2)
      $fatal(1, "missing or duplicate wake: pos=%0d neg=%0d edge=%0d rel=%0d queue=%0d list=%0d mixed=%0d iff=%0d indexed=%0d receiver=%0d",
             pos_count, neg_count, edge_count, relational_count, queue_count,
             list_count, mixed_count, guarded_count, indexed_count, receiver_count);
    if (recipe_count != recipe_count_at_wake)
      $fatal(1, "losing size observer reevaluated after cancellation");
    $display("PASSED");
    $finish(0);
  end
endmodule
