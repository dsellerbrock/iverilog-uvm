// A packed array is one class property. Its indices select bits of that
// property's value, including on writes and when the element is an enum.
module sv_class_packed_enum_property_index;
  typedef enum logic [3:0] {
    Flag1 = 4'h1, Flag2 = 4'h2, Flag3 = 4'h3, Flag9 = 4'h9
  } flag_t;
  typedef enum bit [1:0] {
    TwoZero = 2'd0, TwoOne = 2'd1, TwoTwo = 2'd2
  } two_t;

  class holder;
    flag_t [2:0] flags;
    flag_t [0:2] ascending;
    two_t [1:0] two_state;

    task check();
      int idx;
      flag_t got;
      two_t got_two;

      flags = 12'h123;
      idx = 1;
      flags[idx] = Flag9;
      if (flags !== 12'h193) $fatal(1, "packed write changed neighbors");
      for (idx = 0; idx < 3; idx++) begin
        got = flags[idx];
        if (got !== (idx == 0 ? Flag3 : idx == 1 ? Flag9 : Flag1))
          $fatal(1, "packed read index %0d: %h", idx, got);
      end
      idx = 3;
      got = flags[idx];
      if (got !== 4'hx) $fatal(1, "out-of-range read: %h", got);
      flags[idx] = Flag9;
      if (flags !== 12'h193) $fatal(1, "out-of-range write changed value");

      ascending = 12'h123;
      idx = 0;
      got = ascending[idx];
      if (got !== Flag1) $fatal(1, "ascending index zero: %h", got);
      idx = 2;
      got = ascending[idx];
      if (got !== Flag3) $fatal(1, "ascending index two: %h", got);
      idx = 1;
      ascending[idx] = Flag9;
      if (ascending !== 12'h193)
        $fatal(1, "ascending packed write: %h", ascending);

      two_state = 4'b1001;
      idx = 1;
      got_two = two_state[idx];
      if (got_two !== TwoTwo) $fatal(1, "two-state enum read: %b", got_two);
      idx = 0;
      two_state[idx] = TwoZero;
      if (two_state !== 4'b1000)
        $fatal(1, "two-state enum write: %b", two_state);
      idx = 2;
      got_two = two_state[idx];
      if (got_two !== TwoZero)
        $fatal(1, "out-of-range two-state enum read: %b", got_two);
    endtask
  endclass

  holder h;
  initial begin
    h = new;
    h.check();
    $display("PASSED");
  end
endmodule
