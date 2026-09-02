/*
 * IEEE 1800-2017 7.4, 7.8, 7.10, 7.12: a built-in container method must be
 * dispatched against the object selected by EVERY index component of its
 * receiver, and the method result must have that selected element's type.
 *
 * A receiver carrying two or more index components used to drop all of them
 * and dispatch against the bare root signal, silently returning the wrong
 * object's size. Each nesting level here has a DISTINCT population so any
 * wrong receiver is observable rather than aliasing a correct answer:
 *
 *   qdq        outer queue          2 elements
 *   qdq[0]     dynamic array        3 elements
 *   qdq[0][0]  inner bounded queue  4 elements
 *
 * The typed-result rows pin the companion type-analysis defect: pop_front()
 * on qdq[0][0] yields `int`, not the queue that the one-level-shallow
 * receiver type produced (which failed elaboration as an unpacked aggregate
 * assigned to a scalar).
 */
typedef int   q9_t[$:9];
typedef q9_t  dq_t[];
typedef q9_t  aq_t[int];
typedef dq_t  qdq_t[$];
typedef aq_t  qaq_t[$];

module sv_container_method_multi_index_receiver;

  qdq_t qdq;
  dq_t  dq_value;
  qaq_t qaq;
  aq_t  aq_value;

  int   pass_count = 0;
  int   fail_count = 0;

  task automatic check(string tag, int got, int want);
    if (got == want) begin
      pass_count += 1;
    end else begin
      fail_count += 1;
      $display("FAILED: %s got %0d want %0d", tag, got, want);
    end
  endtask

  int popped;
  int last_elem;

  initial begin
    // Depth-three queue<darray<queue>> with a distinct size at each level.
    dq_value = new[3];
    dq_value[0].push_back(7);
    dq_value[0].push_back(8);
    dq_value[0].push_back(9);
    dq_value[0].push_back(10);
    qdq.push_back(dq_value);
    qdq.push_back(dq_value);

    // Each index level must select its own receiver.
    check("qdq.size", qdq.size(), 2);
    check("qdq[0].size", qdq[0].size(), 3);
    check("qdq[0][0].size", qdq[0][0].size(), 4);

    // A method result takes the fully selected element's type, so this is an
    // int rather than an unpacked queue.
    popped = qdq[0][0].pop_front();
    check("qdq[0][0].pop_front", popped, 7);
    check("qdq[0][0].size after pop", qdq[0][0].size(), 3);

    last_elem = qdq[0][0][$];
    check("qdq[0][0][$]", last_elem, 10);

    // A queue whose element is an associative array of queues: the outer
    // signal is not associative, so this does not travel the associative
    // receiver path.
    aq_value[5].push_back(1);
    aq_value[5].push_back(2);
    aq_value[5].push_back(3);
    qaq.push_back(aq_value);
    qaq.push_back(aq_value);

    check("qaq.size", qaq.size(), 2);
    check("qaq[0][5].size", qaq[0][5].size(), 3);

    // Control: a single-index receiver was never affected and must stay so.
    check("dq_value[0].size", dq_value[0].size(), 4);

    if (fail_count == 0)
      $display("PASSED");
    else
      $display("FAILED: %0d of %0d checks", fail_count, pass_count + fail_count);
  end

endmodule
