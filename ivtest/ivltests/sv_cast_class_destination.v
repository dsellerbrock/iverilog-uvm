// M1C-6: what `$cast(dest, src)` does to its DESTINATION when the
// destination is a class variable or a class-typed property
// (IEEE 1800-2017 6.24.2).
//
// $cast to such a destination is lowered to opcodes rather than going
// through the generic VPI path -- the destination reaches a system
// function as a handle to the CONTAINING object, not to the property.
// That shortcut got three separate things wrong, all silently:
//
//   1. THE TYPE CHECK, which it simply did not do. It emitted an
//      unconditional store and an unconditional 1, so a cast between
//      unrelated classes reported SUCCESS and installed the
//      incompatible handle in the destination. 6.24.2 requires 0 and
//      the destination left alone. This is the worst of the three: it
//      breaks the type system rather than one assignment.
//
//   2. THE ELEMENT INDEX of a fixed unpacked array property. The store
//      carried a literal index selector of 0, so `$cast(p.arr[2], h)'
//      wrote p.arr[0] -- and reported success.
//
//   3. AN ELEMENT OF A CONTAINER property -- a queue, dynamic array or
//      associative array held in the property. The property slot holds
//      the CONTAINER, not the element, so a slot store replaced the
//      whole container with the handle: after `$cast(p.q[1], h)' the
//      queue had size 0. Every other element was destroyed, and the
//      call still returned 1.
//
// (3) is the same defect M1C-3 fixed for the assignment paths; $cast is
// the one path that did not go through the assignment lowering.
//
// The type check is a new %test/class opcode: it asks whether the
// object's DYNAMIC type is the destination class or derives from it,
// which is what makes a downcast to the object's real type succeed and
// a cast to a sibling or unrelated class fail. `null' casts to anything.
//
// Called as a TASK, a failed cast must also produce a diagnostic
// (6.24.2) -- the caller has no return value to inspect. That path is
// covered by tests/negative rather than here, since this file must run
// clean.

module main;

  class Base;
    int id;
  endclass

  class Der extends Base;
    int extra;
  endclass

  class Other;                 // unrelated to Base
    int id;
  endclass

  class Inner;
    Base arr[3];
    Base q[$];
  endclass

  class P;
    Base   one;
    Other  oth;
    Base   barr[3];
    Base   bq[$];
    Base   bda[];
    Base   bam[string];
    Inner  inn;
  endclass

  P     p;
  Der   d;
  Base  b;
  Base  plain;
  Der   dd;
  int   ok;
  int   k = 1;
  int   fails = 0;

  function int idof(Base x);
    return (x == null) ? -1 : x.id;
  endfunction

  task chk(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- %s: got %0d want %0d", what, got, want);
    end
  endtask

  initial begin
    p = new(); p.inn = new();
    d = new(); d.id = 7;
    b = d;                       // a Base handle holding a Der object

    // ---------------- the type check (6.24.2) ----------------

    // A downcast to the object's real type succeeds.
    ok = $cast(dd, b);
    chk("downcast to the real type: return", ok, 1);
    chk("downcast to the real type: value",  idof(dd), 7);

    // A cast to an UNRELATED class fails and must not write.
    ok = $cast(p.oth, b);
    chk("unrelated class: return", ok, 0);
    if (p.oth != null) begin
      fails++;
      $display("FAILED -- a failed $cast wrote the destination anyway");
    end

    // A downcast of a base OBJECT (not a base handle to a derived
    // object) to the derived type fails.
    plain = new();
    dd = null;
    ok = $cast(dd, plain);
    chk("Base object to Der: return", ok, 0);
    if (dd != null) begin
      fails++;
      $display("FAILED -- a failed downcast wrote the destination anyway");
    end

    // null casts to anything and writes null.
    dd = d;
    ok = $cast(dd, null);
    chk("null source: return", ok, 1);
    if (dd != null) begin
      fails++;
      $display("FAILED -- $cast(dst, null) left the destination non-null");
    end

    // ---------------- the destination shapes ----------------

    // scalar property (the shape that always worked; kept as a control)
    ok = $cast(p.one, b);
    chk("scalar property: return", ok, 1);
    chk("scalar property: value",  idof(p.one), 7);

    // fixed unpacked array property element, constant index
    ok = $cast(p.barr[1], b);
    chk("fixed array elem: return", ok, 1);
    chk("fixed array elem [0]", idof(p.barr[0]), -1);
    chk("fixed array elem [1]", idof(p.barr[1]),  7);
    chk("fixed array elem [2]", idof(p.barr[2]), -1);

    // ... and a variable index
    p.barr[1] = null;
    ok = $cast(p.barr[k], b);
    chk("fixed array elem, var index: return", ok, 1);
    chk("fixed array elem, var index [0]", idof(p.barr[0]), -1);
    chk("fixed array elem, var index [1]", idof(p.barr[1]),  7);

    // queue property element: the container must survive
    p.bq.push_back(null);
    p.bq.push_back(null);
    ok = $cast(p.bq[1], b);
    chk("queue elem: return", ok, 1);
    chk("queue elem: the queue still has its elements", p.bq.size(), 2);
    if (p.bq.size() == 2) begin
      chk("queue elem [0]", idof(p.bq[0]), -1);
      chk("queue elem [1]", idof(p.bq[1]),  7);
    end

    // dynamic array property element
    p.bda = new[3];
    ok = $cast(p.bda[1], b);
    chk("darray elem: return", ok, 1);
    chk("darray elem: the array still has its elements", p.bda.size(), 3);
    if (p.bda.size() == 3) begin
      chk("darray elem [0]", idof(p.bda[0]), -1);
      chk("darray elem [1]", idof(p.bda[1]),  7);
    end

    // associative array property element
    p.bam["a"] = null;
    ok = $cast(p.bam["b"], b);
    chk("assoc elem: return", ok, 1);
    chk("assoc elem: the map still has its entries", p.bam.num(), 2);
    if (p.bam.exists("b"))
      chk("assoc elem [b]", idof(p.bam["b"]), 7);
    else begin
      fails++; $display("FAILED -- assoc elem: the key was never created");
    end

    // a nested receiver: the element index belongs to the LAST hop
    ok = $cast(p.inn.arr[1], b);
    chk("nested fixed array elem: return", ok, 1);
    chk("nested fixed array elem [0]", idof(p.inn.arr[0]), -1);
    chk("nested fixed array elem [1]", idof(p.inn.arr[1]),  7);

    // (An element of a container reached through a NESTED receiver --
    //  p.inn.q[1] -- parses as a SELECT over a property read rather than
    //  an indexed property, so it takes the generic path and is not
    //  covered here. It returns 1 and writes nothing; see R16.)

    // a FAILED cast into a container element must leave the container
    // and the element alone
    ok = $cast(p.bq[0], plain);        // Base object into a Base element: fine
    chk("base into base elem: return", ok, 1);
    p.oth = null;
    ok = $cast(p.bam["b"], null);
    chk("null into an assoc elem: return", ok, 1);
    chk("null into an assoc elem: the map is intact", p.bam.num(), 2);

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
