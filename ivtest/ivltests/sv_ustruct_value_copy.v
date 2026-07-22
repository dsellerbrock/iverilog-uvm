// Value semantics of an object-backed unpacked struct on ASSIGNMENT. An
// unpacked struct is a value type (IEEE 1800-2017 7.2): `dst = src` copies
// src's contents into dst, so a later `dst.field = ...` must NOT mutate src.
// Previously the object handle was stored by reference, so `dst = src` aliased
// a single object and mutating one mutated the other. A class handle keeps
// reference semantics and must still alias. Covers scalar, static-array,
// dynamic-array, and queue element assignment targets.
module sv_ustruct_value_copy;
  typedef struct { int a; int b; } s_t;
  class C; int v; endclass

  s_t x, y;
  s_t sa[2];
  s_t da[];
  s_t q[$];
  C h1, h2;
  int errors = 0;

  initial begin
    // Scalar struct assignment is a value copy.
    x.a = 1; x.b = 2;
    y = x;
    y.a = 99;
    if (x.a != 1 || y.a != 99) begin
      $display("FAIL scalar x.a=%0d y.a=%0d", x.a, y.a); errors++; end

    // Mutating the source afterward must not touch the copy.
    x.a = 100;
    if (y.a != 99) begin
      $display("FAIL scalar-src-mutate y.a=%0d (expect 99)", y.a); errors++; end

    // Static array element target.
    x.a = 1;
    sa[0] = x;
    sa[0].a = 55;
    if (x.a != 1 || sa[0].a != 55) begin
      $display("FAIL static-arr x.a=%0d sa0.a=%0d", x.a, sa[0].a); errors++; end

    // Dynamic array element target.
    da = new[2];
    da[0] = x;
    da[0].a = 77;
    if (x.a != 1 || da[0].a != 77) begin
      $display("FAIL dyn-arr x.a=%0d da0.a=%0d", x.a, da[0].a); errors++; end

    // Queue element target.
    q.push_back('{a:0, b:0});
    q[0] = x;
    q[0].a = 88;
    if (x.a != 1 || q[0].a != 88) begin
      $display("FAIL queue x.a=%0d q0.a=%0d", x.a, q[0].a); errors++; end

    // A class handle must keep REFERENCE semantics (assignment aliases).
    h1 = new; h1.v = 10;
    h2 = h1;
    h2.v = 20;
    if (h1.v != 20 || h2.v != 20) begin
      $display("FAIL class-ref h1.v=%0d h2.v=%0d (expect 20,20)", h1.v, h2.v); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
  end
endmodule
