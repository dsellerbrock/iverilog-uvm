// Member access on an element of a DYNAMIC array (and a queue) of an UNPACKED
// struct. The container stores each element as an object; a `new[]`-allocated
// element is lazily default-constructed on first member access, so
// `da[i].field = x` on a never-whole-assigned element addresses a real object
// (previously the write was dropped and the dynamic-array case was diagnosed
// with a `sorry`, while the queue case crashed). A member read of an
// unassigned element returns the struct default (0). %p on an element and on
// the whole container renders `'{field:value, ...}` the same as a static
// array. (IEEE 1800-2017 7.2.1.)
module sv_dyn_array_member;
  typedef struct { int a; int b; } s_t;
  s_t da[];
  s_t q[$];
  int errors = 0;

  initial begin
    da = new[3];

    // Read before any write: default-constructed element reads as 0.
    if (da[0].a != 0 || da[2].b != 0) begin
      $display("FAIL default da[0].a=%0d da[2].b=%0d", da[0].a, da[2].b); errors++; end

    // Member writes to never-whole-assigned elements (including a negative).
    da[0].a = -5; da[0].b = 6;
    da[2].a = 100;
    // Leave da[1] untouched (stays default 0).
    if (da[0].a != -5 || da[0].b != 6) begin
      $display("FAIL da[0]=(%0d,%0d)", da[0].a, da[0].b); errors++; end
    if (da[1].a != 0 || da[1].b != 0) begin
      $display("FAIL da[1]=(%0d,%0d) (expect 0,0)", da[1].a, da[1].b); errors++; end
    if (da[2].a != 100 || da[2].b != 0) begin
      $display("FAIL da[2]=(%0d,%0d)", da[2].a, da[2].b); errors++; end

    // A member write after a whole-element assign also works.
    da[1] = '{a:7, b:8};
    da[1].a = 9;
    if (da[1].a != 9 || da[1].b != 8) begin
      $display("FAIL da[1] after mix=(%0d,%0d)", da[1].a, da[1].b); errors++; end

    // Queue element member access (each entry stored as an object). Member
    // writes to a queue element used to crash; now they address the element.
    q.push_back('{a:1, b:2});
    q.push_back('{a:3, b:4});
    q[0].a = 42;
    if (q[0].a != 42 || q[0].b != 2) begin
      $display("FAIL q[0]=(%0d,%0d)", q[0].a, q[0].b); errors++; end
    if (q[1].a != 3 || q[1].b != 4) begin
      $display("FAIL q[1]=(%0d,%0d)", q[1].a, q[1].b); errors++; end

    // %p renders element and whole-array object contents. da[1] was written
    // above to (9,8); da[2] to (100,0).
    $display("da1=%p", da[1]);
    $display("da=%p", da);
    $display("q0=%p", q[0]);

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
  end
endmodule
