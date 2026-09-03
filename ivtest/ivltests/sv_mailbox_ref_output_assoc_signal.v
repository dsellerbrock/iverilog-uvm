// IEEE 1800-2017/2023 15.4.5-15.4.8 with 7.8: a mailbox retrieval whose ref
// target is an element of a signal-backed ASSOCIATIVE ARRAY must create that
// element and write the retrieved message into it.
//
// An associative-array variable that has never been written still holds nil,
// because its empty default container is materialized lazily on first
// l-value access. The ref capture ran against that nil and silently dropped
// the retrieval: the element was never created, so the target read back as
// its default and size() stayed 0, with no diagnostic at compile or run time.
//
// Baselines, both measured, because they differ:
//   - on this branch before the fix, only a never-written map failed; a map
//     written first already worked (fixed earlier by the class-property
//     capture change), so `primed' below is a genuine control;
//   - on origin/main at dcd3f8fc1, BOTH fail -- the primed checks are red
//     there too. Do not read `primed' as untouched by that commit.
//
// All four element representations the capture can select are covered --
// vec4, string, real and object -- because the container class is chosen from
// the value kind, so each arm is a separate code path. A string key is
// included because the key type is an axis independent of the element type.
class holder;
  int x;
endclass

module sv_mailbox_ref_output_assoc_signal;

  mailbox #(int)    mi;
  mailbox #(string) ms;
  mailbox #(real)   mr;
  mailbox #(holder) mh;

  int    vm [int];      // never written before the get
  string sm [int];
  real   rm [int];
  holder om [int];      // object element kind
  int    km [string];   // string key
  int    primed [int];  // written first: see the baseline note above
  int    never [int];   // only ever the target of a FAILING try_get

  int fails = 0;

  task automatic ck_int(string tag, int got, int want);
    if (got != want) begin
      fails += 1;
      $display("FAILED: %s got %0d want %0d", tag, got, want);
    end
  endtask

  initial begin
    holder h;

    mi = new();
    ms = new();
    mr = new();
    mh = new();

    mi.put(9);
    mi.get(vm[3]);
    ck_int("vec4 element", vm[3], 9);
    ck_int("vec4 size",    vm.size(), 1);

    ms.put("hi");
    ms.get(sm[4]);
    if (sm[4] != "hi") begin
      fails += 1;
      $display("FAILED: string element got '%s' want 'hi'", sm[4]);
    end
    ck_int("string size", sm.size(), 1);

    mr.put(2.5);
    mr.get(rm[5]);
    if (rm[5] != 2.5) begin
      fails += 1;
      $display("FAILED: real element got %0f want 2.5", rm[5]);
    end
    ck_int("real size", rm.size(), 1);

    h = new;
    h.x = 4;
    mh.put(h);
    mh.get(om[2]);
    if (om[2] == null) begin
      fails += 1;
      $display("FAILED: object element is null");
    end
    else
      ck_int("object element", om[2].x, 4);
    ck_int("object size", om.size(), 1);

    mi.put(11);
    mi.get(km["key"]);
    ck_int("string-key element", km["key"], 11);
    ck_int("string-key size",    km.size(), 1);

    // Control for the branch baseline: a map written before the retrieval.
    primed[1] = 5;
    mi.put(7);
    mi.get(primed[3]);
    ck_int("primed element", primed[3], 7);
    ck_int("primed size",    primed.size(), 2);

    // A failing try_get must not leave an element behind. The capture
    // materializes the empty container BEFORE it knows the retrieval will
    // succeed, so this is checked on a map that is still nil at that point,
    // not merely on one an earlier successful get already materialized.
    if (mi.try_get(never[7])) begin
      fails += 1;
      $display("FAILED: try_get on an empty mailbox returned 1");
    end
    ck_int("never size",   never.size(), 0);
    ck_int("never exists", never.exists(7), 0);

    // The same, on a map an earlier successful get did materialize.
    if (mi.try_get(vm[99])) begin
      fails += 1;
      $display("FAILED: second try_get on an empty mailbox returned 1");
    end
    ck_int("size after empty try", vm.size(), 1);

    if (fails == 0)
      $display("PASSED");
  end

endmodule
