// A bad inner packed index must not carry into a neighboring outer element.
module sv_class_packed_property_2d_index;
  typedef enum logic [3:0] { A=4'h1, B=4'h2, C=4'h3, D=4'h4 } flag_t;
  typedef enum bit [1:0] { Zero=0, One=1, Two=2 } two_t;
  typedef two_t [1:0] inner_t;
  typedef inner_t [1:0] outer_t;

  class holder;
    flag_t [1:0][1:0] flags;
    logic [1:0][1:0] bits;
    outer_t nested;

    task check();
      flag_t got;
      two_t got_two;
      int outer_idx, inner_idx;

      flags = 16'h1234;
      got = flags[0][2];
      if (got !== 4'hx) $fatal(1, "constant bad inner read: %h", got);
      flags[0][2] = D;
      if (flags !== 16'h1234)
        $fatal(1, "constant bad inner write: %h", flags);

      outer_idx = 0;
      inner_idx = 2;
      got = flags[outer_idx][inner_idx];
      if (got !== 4'hx) $fatal(1, "variable bad inner read: %h", got);
      flags[outer_idx][inner_idx] = D;
      if (flags !== 16'h1234)
        $fatal(1, "variable bad inner write: %h", flags);
      inner_idx = 0;
      got = flags[outer_idx][inner_idx++];
      if (got !== D || inner_idx != 1)
        $fatal(1, "read index evaluated more than once");
      flags[outer_idx][inner_idx++] = D;
      if (flags !== 16'h1244 || inner_idx != 2)
        $fatal(1, "write index evaluated more than once");

      bits = 4'b1010;
      if (bits[0][2] !== 1'bx)
        $fatal(1, "plain packed-vector bad read");
      bits[0][2] = 1'b1;
      if (bits !== 4'b1010)
        $fatal(1, "plain packed-vector bad write: %b", bits);

      // A valid trailing range stays in its inner dimension, while a bad
      // leading element index must make the whole mixed select invalid.
      if (bits[0][1:0] !== 2'b10)
        $fatal(1, "valid inner part read");
      bits[0][1:0] = 2'b11;
      if (bits !== 4'b1011)
        $fatal(1, "valid inner part write: %b", bits);
      bits = 4'b1010;
      if (bits[0][0 +: 2] !== 2'b10)
        $fatal(1, "valid inner indexed read");
      bits[0][0 +: 2] = 2'b01;
      if (bits !== 4'b1001)
        $fatal(1, "valid inner indexed write: %b", bits);
      bits = 4'b1010;
      outer_idx = 2;
      if (bits[outer_idx][1:0] !== 2'bxx)
        $fatal(1, "bad outer part read");
      bits[outer_idx][1:0] = 2'b11;
      if (bits !== 4'b1010)
        $fatal(1, "bad outer part write: %b", bits);
      if (bits[outer_idx][0 +: 2] !== 2'bxx)
        $fatal(1, "bad outer indexed read");
      bits[outer_idx][0 +: 2] = 2'b11;
      if (bits !== 4'b1010)
        $fatal(1, "bad outer indexed write: %b", bits);

      nested = 8'h12;
      outer_idx = 0;
      inner_idx = 0;
      got_two = nested[outer_idx][inner_idx];
      if (got_two !== Two) $fatal(1, "nested enum read: %b", got_two);
      inner_idx = 2;
      got_two = nested[outer_idx][inner_idx];
      if (got_two !== Zero)
        $fatal(1, "nested enum bad inner read: %b", got_two);
      nested[outer_idx][inner_idx] = One;
      if (nested !== 8'h12)
        $fatal(1, "nested enum bad inner write: %b", nested);
      inner_idx = 0;
      nested[outer_idx][inner_idx] = One;
      if (nested !== 8'h11)
        $fatal(1, "nested enum write: %b", nested);
    endtask
  endclass

  holder h;
  initial begin
    h = new;
    h.check();
    $display("PASSED");
  end
endmodule
