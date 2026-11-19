class index_cycle;
  rand bit a[];
  rand bit b;
  constraint c {
    solve a[0] before b;
    solve b before a[32'd0];
    a.size() == 1;
    a[0] != b;
  }
endclass

`ifdef ISSUE3831_UNSAFE
class order_base;
  rand bit a, s, t;
  rand bit [1:0] b;
  bit required_bit = 1;
  function bit required_value;
    return required_bit;
  endfunction

  constraint forward_c {
    solve a, s, t before b;
    required_value() == 1;
    (a || s) -> b == 0;
  }
endclass

class order_cyclic extends order_base;
  constraint back_c { solve b before a; solve t before t; }
endclass

class order_restored extends order_cyclic;
  constraint back_c {}
endclass

typedef struct packed { bit a, s; } order_fields;
class order_packed;
  rand order_fields fields;
  rand bit [1:0] b;
  constraint c {
    solve fields before b;
    solve b before this.fields.a;
    fields.s -> b == 0;
  }
endclass
`endif

module test;
  index_cycle indexed = new;
`ifdef ISSUE3831_UNSAFE
  order_cyclic mixed = new;
  order_restored restored = new;
  order_packed packed_mixed = new;
  int mixed_s, mixed_a_without_s, restored_s, restored_a_without_s;
  int packed_s;

  initial begin
    if (!indexed.randomize() || indexed.a.size() != 1 ||
        indexed.a[0] == indexed.b)
      $fatal(1, "dynamic element cycle lost its value constraints");
    mixed.srandom(32'h383101);
    restored.srandom(32'h383102);
    packed_mixed.srandom(32'h383103);
    repeat (768) begin
      if (!mixed.randomize() || ((mixed.a || mixed.s) && mixed.b != 0))
        $fatal(1, "mixed order lost its value constraint");
      if (!restored.randomize() || ((restored.a || restored.s) && restored.b != 0))
        $fatal(1, "restored order lost its value constraint");
      if (!packed_mixed.randomize() ||
          (packed_mixed.fields.s && packed_mixed.b != 0))
        $fatal(1, "packed order lost its value constraint");
      if (mixed.s) mixed_s++;
      else if (mixed.a) mixed_a_without_s++;
      if (restored.s) restored_s++;
      else if (restored.a) restored_a_without_s++;
      if (packed_mixed.fields.s) packed_s++;
    end

    // Without s -> b, P(s) = 2/7. With it, P(s) = 1/2.
    // Given s == 0, P(a) = 1/5 with a -> b removed and 1/2 once restored.
    if (mixed_s < 320 || mixed_s > 448 ||
        mixed_a_without_s < 40 || mixed_a_without_s > 120)
      $fatal(1, "mixed order distribution s=%0d a&s0=%0d", mixed_s, mixed_a_without_s);
    if (restored_s < 320 || restored_s > 448 ||
        restored_a_without_s < 140 || restored_a_without_s > 244)
      $fatal(1, "override did not restore order s=%0d a&s0=%0d",
             restored_s, restored_a_without_s);
    // The surviving packed slice has a uniform marginal instead of 1/5.
    if (packed_s < 320 || packed_s > 448)
      $fatal(1, "packed order distribution s=%0d", packed_s);

    mixed.required_bit = 0;
    if (mixed.randomize())
      $fatal(1, "inherited state constraint was lost");
    mixed.forward_c.constraint_mode(0);
    if (!mixed.randomize())
      $fatal(1, "inherited constraint activation changed");
    $display("PASSED");
  end
`endif
endmodule
