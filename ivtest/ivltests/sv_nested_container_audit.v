// M4B-3: adversarial nested-container audit (IEEE 1800-2017 clause 7). Deep
// combinations of queues, dynamic arrays, associative arrays, structs, and
// class properties — including member writes into container elements.
// Self-checking. (Array-of-queue is a separate, loudly-diagnosed limitation.)
typedef struct { int a; int b; } p_t;
typedef struct { int da[]; } s_t;
typedef struct { int a; } el_t;
typedef int bounded_q_t[$:1];

class Holder;
  el_t items[$];
  int bounded[$:1];
  int bounded_slots[2][$:1];
  int aq[string][$];
endclass

module sv_nested_container_audit;
  p_t q[$];
  s_t s;
  int aq[string][$];
  el_t assoc_struct[string];
  int wake_aaa[string][string][string];
  bounded_q_t bounded_assoc[string][int];
  bounded_q_t bounded_pos[string][$];
  logic signed [15:0] width_aa[string][string];
  int typed_key_aa[byte][string];
  int dd[][];
  int assoc_dd[string][];
  int queue_dd[$][];
  int fixed_source[2:0];
  int errors = 0;
  bit woke;

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

    // Materializing an object-backed associative element for a member lvalue
    // is itself an outer-array change, and the selected object must retain
    // provenance so a later member store wakes the same observers.
    begin
      woke = 0;
      fork begin wait (assoc_struct.exists("created")); woke = 1; end join_none
      #0;
      assoc_struct["created"].a = 5;
      #0;
      if (!woke || assoc_struct["created"].a != 5) begin
        $display("FAIL assoc struct insertion notification woke=%0d", woke);
        errors++;
      end

      woke = 0;
      fork begin wait (assoc_struct["created"].a == 6); woke = 1; end join_none
      #0;
      assoc_struct["created"].a = 6;
      #0;
      if (!woke) begin
        $display("FAIL assoc struct child notification");
        errors++;
      end
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

      // Creating the missing queue and mutating the child both notify the
      // outer associative signal. The child receiver must retain the outer
      // root provenance across %aa/viv.
      woke = 0;
      fork begin wait (aq["wake"].size() == 1); woke = 1; end join_none
      #0;
      aq["wake"].push_back(5);
      #0;
      if (!woke || !aq.exists("wake") || aq["wake"][0] != 5) begin
        $display("FAIL assoc viv notification woke=%0d exists=%0d size=%0d",
                 woke, aq.exists("wake"), aq["wake"].size());
        errors++;
      end

      woke = 0;
      fork begin wait (aq["wake"].size() == 2); woke = 1; end join_none
      #0;
      aq["wake"].push_back(6);
      #0;
      if (!woke || aq["wake"][1] != 6) begin
        $display("FAIL assoc child notification woke=%0d size=%0d",
                 woke, aq["wake"].size());
        errors++;
      end

      // A deeper assoc-of-assoc l-value uses both signal and object vivify
      // forms before its final store; root notification must survive both.
      woke = 0;
      fork begin
        wait (wake_aaa["outer"]["middle"]["leaf"] == 88);
        woke = 1;
      end join_none
      #0;
      wake_aaa["outer"]["middle"]["leaf"] = 88;
      #0;
      if (!woke) begin
        $display("FAIL deep assoc viv notification");
        errors++;
      end
    end

    // A bounded queue remains bounded when it is the object-valued final leaf
    // of either an associative or positional deep store. Runtime value-copy
    // alone cannot recover the leaf's declared bound, so lowering trims a
    // private copy and leaves the source unchanged.
    begin
      int source[$];
      bounded_q_t expected;
      source = {10, 20, 30};
      expected = {10, 20};
      bounded_assoc["outer"][7] = source;
      bounded_pos["outer"][0] = source;
      if (source.size() != 3 ||
          bounded_assoc["outer"][7] != expected ||
          bounded_pos["outer"][0] != expected) begin
        $display("FAIL nested bounded leaf src=%0d assoc=%p pos=%p",
                 source.size(), bounded_assoc["outer"][7],
                 bounded_pos["outer"][0]);
        errors++;
      end
    end

    // Chained stores use the declared leaf width, including signed extension
    // and truncation, rather than retaining the RHS expression width.
    begin
      logic signed [3:0] narrow;
      int wide_key;
      byte narrow_key;
      narrow = -1;
      width_aa["outer"]["sign"] = narrow;
      width_aa["outer"]["trunc"] = 32'h12345678;
      if (width_aa["outer"]["sign"] !== 16'hffff ||
          width_aa["outer"]["trunc"] !== 16'h5678) begin
        $display("FAIL nested width sign=%h trunc=%h",
                 width_aa["outer"]["sign"], width_aa["outer"]["trunc"]);
        errors++;
      end

      wide_key = 511;
      narrow_key = -1;
      typed_key_aa[wide_key]["leaf"] = 71;
      if (typed_key_aa[narrow_key]["leaf"] != 71) begin
        $display("FAIL nested key cast=%0d",
                 typed_key_aa[narrow_key]["leaf"]);
        errors++;
      end
    end

    // A missing dynamic-array child has no implicit size. An associative
    // assignment target allocates the missing entry (7.8.7), but its darray
    // value remains nil rather than becoming a growable queue. Initialized
    // children still accept in-range stores.
    begin
      int empty_da[];
      int live_da[];
      live_da = new[1];
      live_da[0] = 7;
      dd = new[2];
      dd[1] = live_da;
      assoc_dd["nil"] = empty_da;
      assoc_dd["live"] = live_da;
      queue_dd.push_back(empty_da);
      queue_dd.push_back(live_da);

      dd[0][0] = 31;
      assoc_dd["nil"][0] = 32;
      assoc_dd["missing"][0] = 34;
      queue_dd[0][0] = 33;
      if (dd[0].size() != 0 || assoc_dd["nil"].size() != 0 ||
          !assoc_dd.exists("missing") ||
          assoc_dd["missing"].size() != 0 || queue_dd[0].size() != 0) begin
        $display("FAIL darray viv da=%0d assoc=%0d missing=%0d queue=%0d",
                 dd[0].size(), assoc_dd["nil"].size(),
                 assoc_dd.exists("missing"), queue_dd[0].size());
        errors++;
      end

      dd[1][0] = 41;
      assoc_dd["live"][0] = 42;
      queue_dd[1][0] = 43;
      if (dd[1][0] != 41 || assoc_dd["live"][0] != 42 ||
          queue_dd[1][0] != 43) begin
        $display("FAIL live darray da=%0d assoc=%0d queue=%0d",
                 dd[1][0], assoc_dd["live"][0], queue_dd[1][0]);
        errors++;
      end
    end

    // Class property queue of structs, with member write into an element.
    begin
      automatic Holder h = new;
      int bounded_source[$];
      int dropped;
      el_t e; e.a = 3; h.items.push_back(e);
      if (h.items[0].a != 3) begin $display("FAIL class-queue el=%0d", h.items[0].a); errors++; end
      h.items[0].a = 99;  // member WRITE into a class-property queue element
      if (h.items[0].a != 99) begin $display("FAIL class-queue write=%0d", h.items[0].a); errors++; end

      woke = 0;
      fork begin wait (h.aq["notify"].size() == 1); woke = 1; end join_none
      #0;
      h.aq["notify"].push_back(7);
      #0;
      if (!woke || !h.aq.exists("notify") || h.aq["notify"][0] != 7) begin
        $display("FAIL class assoc viv notification woke=%0d", woke);
        errors++;
      end

      bounded_source = {1, 2, 3};
      h.bounded = bounded_source;
      if (h.bounded.size() != 2 || h.bounded[0] != 1 ||
          h.bounded[1] != 2 || bounded_source.size() != 3) begin
        $display("FAIL scalar bounded property dst=%0d src=%0d",
                 h.bounded.size(), bounded_source.size());
        errors++;
      end

      // A bare fixed array must be materialized as a real queue (not a
      // dynamic-array object) for both scalar and selected fixed-array queue
      // properties. Preserve declared order, enforce each destination bound,
      // and keep the assigned values independent of later source writes.
      fixed_source = '{4, 5, 6};
      h.bounded = fixed_source;
      h.bounded_slots[0] = fixed_source;
      fixed_source[2] = 99;
      dropped = h.bounded.pop_front();
      h.bounded.push_back(8);
      if (dropped != 4 || h.bounded.size() != 2 ||
          h.bounded[0] != 5 || h.bounded[1] != 8 ||
          h.bounded_slots[0].size() != 2 ||
          h.bounded_slots[0][0] != 4 || h.bounded_slots[0][1] != 5) begin
        $display("FAIL fixed-to-property queue drop=%0d scalar=%p slot=%p",
                 dropped, h.bounded, h.bounded_slots[0]);
        errors++;
      end
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
