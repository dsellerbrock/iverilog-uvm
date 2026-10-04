module top;
  int unsigned mutable[int unsigned];
  logic [3:0] four_state[logic [3:0]];
  int unsigned cursor;
  logic [3:0] state_cursor;

  initial begin
    mutable[10] = 10;
    mutable[20] = 20;
    mutable[30] = 30;
    if (!mutable.first(cursor) || cursor != 10)
      $fatal(1, "mutation case: first did not return 10");
    mutable.delete(20);
    if (!mutable.next(cursor) || cursor != 30)
      $fatal(1, "mutation case: deleted successor was not skipped");

    cursor = 10;
    mutable[15] = 15;
    if (!mutable.next(cursor) || cursor != 15)
      $fatal(1, "mutation case: insertion after cursor was not visible");
    mutable.delete(15);
    if (!mutable.next(cursor) || cursor != 30)
      $fatal(1, "mutation case: deleted cursor successor was not skipped");

    four_state[4'b0000] = 0;
    four_state[4'b1000] = 1;
    four_state[4'bx000] = 2;
    four_state[4'bz000] = 3;
    if (!four_state.first(state_cursor) || state_cursor !== 4'b0000)
      $fatal(1, "four-state first order mismatch: %b", state_cursor);
    if (!four_state.next(state_cursor) || state_cursor !== 4'b1000)
      $fatal(1, "four-state 1 order mismatch: %b", state_cursor);
    if (!four_state.next(state_cursor) || state_cursor !== 4'bx000)
      $fatal(1, "four-state X order mismatch: %b", state_cursor);
    if (!four_state.next(state_cursor) || state_cursor !== 4'bz000)
      $fatal(1, "four-state final order mismatch: %b", state_cursor);
    if (four_state.next(state_cursor))
      $fatal(1, "four-state next continued after final key");

    $display("PASS flash_aa_semantics mutation=delete-successor,insert-after-cursor,delete-cursor; four-state=0<1<X<Z");
    $finish;
  end
endmodule
