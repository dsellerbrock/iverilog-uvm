// M4B-3: adversarial nested-container audit (IEEE 1800-2017 clause 7). Deep
// combinations of queues, dynamic arrays, associative arrays, structs, and
// class properties — including member writes into container elements.
// Self-checking. (Array-of-queue is a separate, loudly-diagnosed limitation.)
typedef struct { int a; int b; } p_t;
typedef struct { int da[]; } s_t;
typedef struct { int a; } el_t;

class Holder; el_t items[$]; endclass

module sv_nested_container_audit;
  p_t q[$];
  s_t s;
  int aq[string][$];
  int errors = 0;

  initial begin
    // Queue of structs: value-copy on push, and member write into an element.
    begin
      p_t x; x.a = 1; x.b = 2; q.push_back(x);
      x.a = 9;            x.b = 8; q.push_back(x);
      if (q[0].a != 1 || q[0].b != 2) begin $display("FAIL qcopy q0=%p", q[0]); errors++; end
      if (q[1].a != 9) begin $display("FAIL q1=%0d", q[1].a); errors++; end
      q[0].a = 100;       // member WRITE into a queue element
      if (q[0].a != 100) begin $display("FAIL qwrite=%0d", q[0].a); errors++; end
    end

    // Struct containing a dynamic array.
    begin
      s.da = new[3]; s.da[0] = 10; s.da[1] = 20; s.da[2] = 30;
      if (s.da.size() != 3 || s.da[1] != 20) begin $display("FAIL struct-darray"); errors++; end
    end

    // Associative array of queues.
    begin
      aq["x"].push_back(1); aq["x"].push_back(2); aq["y"].push_back(9);
      if (aq["x"].size() != 2 || aq["x"][1] != 2 || aq["y"][0] != 9) begin $display("FAIL assoc-of-queue"); errors++; end
    end

    // Class property queue of structs, with member write into an element.
    begin
      automatic Holder h = new;
      el_t e; e.a = 3; h.items.push_back(e);
      if (h.items[0].a != 3) begin $display("FAIL class-queue el=%0d", h.items[0].a); errors++; end
      h.items[0].a = 99;  // member WRITE into a class-property queue element
      if (h.items[0].a != 99) begin $display("FAIL class-queue write=%0d", h.items[0].a); errors++; end
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
