// Event merging must not cross an automatic call-frame boundary.
//
// NetEvent::find_similar_event merges two wait(...) expressions that have
// identical probe sets. The runtime keeps event state for a scope that owns
// a call frame inside that scope's automatically allocated context, so such
// an event may only merge with one in the very same scope. The guard was
// one-sided: it skipped the merge when the event being placed was itself in
// an automatic scope, but not when it was in a STATIC scope and the
// candidate was in an automatic one. The survivor then became context-local
// and the static-scope waiter had no context to resolve it in, aborting in
// vthread_add_event_wait on a null wait-list head.
//
// Here the two wait(...) expressions are identical. The first runs in the
// module's static initial block; the second runs inside a named block that
// holds an automatic declaration and therefore owns a call frame.
module sv_auto_block_shared_wait_event;

  class watched_state;
    bit watched;
  endclass

  watched_state state;
  bit ordinary;
  bit first_woke;
  int loop_wakes;

  initial begin
    state = new;

    fork
      begin
        wait (state.watched && ordinary);
        first_woke = 1;
      end
    join_none
    #1; state.watched = 1;
    #1; ordinary = 1;
    #1;

    ordinary = 1;
    begin : automatic_frame_block
      automatic int iteration;
      for (iteration = 0; iteration < 3; iteration = iteration + 1) begin
        state.watched = 0;
        fork
          begin
            wait (state.watched && ordinary);
            loop_wakes = loop_wakes + 1;
          end
        join_none
        #1; state.watched = 1;
        #1;
      end
    end

    if (!first_woke) begin
      $display("FAILED: static-scope mixed wait never completed");
    end else if (loop_wakes !== 3) begin
      $display("FAILED: automatic-frame waiters woke %0d times", loop_wakes);
    end else begin
      $display("PASSED");
    end
    $finish(0);
  end

endmodule
