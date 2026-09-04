// IEEE 1800-2017/2023 13.5.2: a `ref' argument is a reference to the actual.
// Icarus binds a QUEUE (or darray/assoc/fixed-array) ref formal by
// VALUE-COPY -- copy in at the call, copy out at the return -- and reports
// that deviation when it can matter.
//
// It can only matter for a write that happens in a branch still running when
// the task returns, and reaching the formal from such a branch requires
// referring to it inside a fork-join_any/join_none. IEEE 1800-2017 9.3.2
// makes exactly that illegal:
//
//   "Within a fork-join_any or fork-join_none block, it shall be illegal to
//    refer to formal arguments passed by reference other than in the
//    initialization value expressions of variables declared in a
//    block_item_declaration of the fork."
//
// So in LEGAL code the deviation is unobservable, and the diagnostic used to
// fire on any task that merely CONTAINED a detached fork anywhere -- even one
// that never touches the formal. OpenTitan's glitch_shadowed_reset
// (cip_base_vseq__shadow_reg_errors.svh) is that shape: it only reads the
// queue, at the top of the task, while its detached fork comes from a
// DV_SPINWAIT expansion that never mentions it.
//
// This test pins the LEGAL shape: an unrelated detached fork must not change
// ref-formal behaviour, and writes through the reference must still reach the
// caller's actual.
//
// slang 11.0.448 accepts this file under both editions.

module main;

  int errors = 0;

  task automatic chk(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAILED: %s got %0d want %0d", what, got, exp);
      errors += 1;
    end
  endtask

  // Reads the formal, and writes it -- but only from the task's own thread.
  // The detached fork below never refers to `r'.
  task automatic touch(ref int r[$], output int sum);
    sum = 0;
    foreach (r[i]) sum += r[i];
    fork
      begin : unrelated
        #1 $display("unrelated branch ran");
      end
    join_none
    r.push_back(99);          // write through the reference, own thread
    #2;
  endtask

  // No fork at all: the plain reference case, for contrast.
  task automatic plain(ref int r[$]);
    r.push_back(7);
  endtask

  int q[$];
  int total;

  initial begin
    q.push_back(3);
    q.push_back(4);

    plain(q);
    chk("plain size",  q.size(), 3);
    chk("plain back",  q[2],     7);

    touch(q, total);
    chk("sum seen by callee", total,    14);  // 3 + 4 + 7
    chk("write reached caller", q.size(), 4);
    chk("written value",       q[3],    99);

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d error(s)", errors);
  end

endmodule
