// Value semantics of an object-backed unpacked struct through container-INSERT
// methods and nested structs (IEEE 1800-2017 7.2). A struct is a value type, so
// inserting a struct variable into a queue/associative array must store an
// independent copy — a later mutation of the source (or of the stored element)
// must not affect the other. Previously the container methods stored the
// struct's object handle by reference, so `q.push_back(x); x.a = ...` mutated
// q[0] too. A class handle keeps REFERENCE semantics and must still alias.
// Also confirms nested unpacked structs copy deeply (they already did — the
// nested fields are value members, not a shared sub-handle).
module sv_ustruct_value_copy_containers;
  typedef struct { int a; int b; } s_t;
  typedef struct { s_t i; int c; } nest_t;   // nested unpacked struct
  class C; int v; endclass

  s_t   x;
  s_t   q[$];
  s_t   aa[int];
  nest_t o1, o2;
  nest_t nq[$];
  nest_t m;
  C     h1;
  C     cq[$];
  int   errors = 0;

  initial begin
    // push_back(var): stored copy is independent of the source.
    x.a = 1; x.b = 2;
    q.push_back(x);
    x.a = 50;
    if (q[0].a != 1 || q[0].b != 2) begin
      $display("FAIL push_back q0=(%0d,%0d)", q[0].a, q[0].b); errors++; end

    // push_front(var).
    x.a = 3;
    q.push_front(x);
    x.a = 60;
    if (q[0].a != 3) begin $display("FAIL push_front q0.a=%0d", q[0].a); errors++; end

    // insert(idx, var).
    x.a = 9;
    q.insert(1, x);
    x.a = 70;
    if (q[1].a != 9) begin $display("FAIL insert q1.a=%0d", q[1].a); errors++; end

    // Mutating the stored element must not affect the original either.
    x.a = 100; x.b = 200;
    aa[5] = x;
    aa[5].a = 111;
    if (x.a != 100 || aa[5].a != 111) begin
      $display("FAIL assoc x.a=%0d aa5.a=%0d", x.a, aa[5].a); errors++; end

    // A class handle keeps REFERENCE semantics through the same method.
    h1 = new; h1.v = 7;
    cq.push_back(h1);
    h1.v = 8;
    if (cq[0].v != 8) begin
      $display("FAIL class-ref cq0.v=%0d (expect 8)", cq[0].v); errors++; end

    // Nested unpacked struct: assignment copies deeply (3 levels here via 2).
    o1.i.a = 1; o1.i.b = 2; o1.c = 3;
    o2 = o1;
    o2.i.a = 88;
    if (o1.i.a != 1 || o2.i.a != 88) begin
      $display("FAIL nested-assign o1.i.a=%0d o2.i.a=%0d", o1.i.a, o2.i.a); errors++; end

    // Nested struct pushed into a queue, then source mutated.
    m.i.a = 5; m.c = 6;
    nq.push_back(m);
    m.i.a = 55;
    if (nq[0].i.a != 5 || m.i.a != 55) begin
      $display("FAIL nested-push nq0.i.a=%0d m.i.a=%0d", nq[0].i.a, m.i.a); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
  end
endmodule
