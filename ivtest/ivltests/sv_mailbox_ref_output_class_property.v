// IEEE 1800-2017/2023 15.4.5-15.4.8: a mailbox get/peek/try_get/try_peek
// target is taken by ref, and it may name storage inside an object rather
// than a signal.
//
// A property target reached DIRECTLY through a handle signal (h.value,
// h.values[0], h.int_map[5]) rather than through a nested l-value used to
// take the plain-signal path and capture the class HANDLE instead of the
// property:
//
//   - the indexed spellings reported "sorry: unsupported indexed mailbox
//     ref-output signal shape"; while
//   - the unindexed spelling compiled silently and then aborted vvp with
//     "internal error: 24vvp_fun_signal_object_sa: recv_vec4 not
//     implemented" when the retrieved value was written back.
//
// The signal spellings alongside them are kept here so the property fix is
// pinned against the paths that already worked.
class mailbox_ref_property_holder;
  int value;
  int values [$];
  int int_map [int];
endclass

module sv_mailbox_ref_output_class_property;

  mailbox #(int) mi;
  mailbox_ref_property_holder holder;
  int signal_queue [$];
  int fails = 0;

  task automatic ck(string tag, int got, int want);
    if (got != want) begin
      fails += 1;
      $display("FAILED: %s got %0d want %0d", tag, got, want);
    end
  endtask

  initial begin
    mi = new();
    holder = new();
    holder.values.push_back(0);
    signal_queue.push_back(0);

    // Unindexed property: used to compile clean and then abort vvp.
    mi.put(7);
    mi.get(holder.value);
    ck("property scalar", holder.value, 7);

    // Indexed container property: used to be rejected outright.
    mi.put(10);
    mi.get(holder.values[0]);
    ck("property queue element", holder.values[0], 10);

    mi.put(11);
    mi.get(holder.int_map[5]);
    ck("property assoc element", holder.int_map[5], 11);

    // A signal-backed queue element keeps working.
    mi.put(8);
    mi.get(signal_queue[0]);
    ck("signal queue element", signal_queue[0], 8);

    // A try_ variant through a property must also write back.
    mi.put(12);
    if (!mi.try_get(holder.values[0]))
      begin
        fails += 1;
        $display("FAILED: try_get through a property returned 0");
      end
    ck("property queue try_get", holder.values[0], 12);

    // An empty try_ must leave the property untouched.
    if (mi.try_get(holder.value)) begin
      fails += 1;
      $display("FAILED: try_get on an empty mailbox returned 1");
    end
    ck("property scalar after empty try", holder.value, 7);

    if (fails == 0)
      $display("PASSED");
  end

endmodule
