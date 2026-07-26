// M1C: accessing an ELEMENT of a container held in a CLASS PROPERTY.
//
// The container being a class property is the load-bearing axis: every
// module-scope control here already passed. Three silent defects, all of
// which this test would have caught:
//
// 1. NULL GUARDS FAILED OPEN. `obj.arr[i] == null` was lowered to
//    %test_nul/prop, which tests the PROPERTY SLOT. For a dynamic array,
//    queue or associative-array property the slot holds the CONTAINER,
//    which is never null -- so a null element compared as non-null, with
//    no diagnostic, and the lazy-allocation idiom
//        if (arr[i] == null) arr[i] = new();
//    silently skipped the allocation. Index >= 1 aborted the runtime
//    outright (assert idx < array_size_). A fixed-size unpacked array
//    property was unaffected: there the index really is a slot index.
//
// 2. WHOLE-ELEMENT STORES OF AN UNPACKED STRUCT ALIASED THE SOURCE. An
//    object-backed unpacked struct is a VALUE (IEEE 1800-2017 7.2), but
//    the property-container store pushed the r-value's handle straight
//    into the slot, so every element written from one struct variable
//    ended up sharing it: writing 10,11,12,13 in a loop left 13,13,13,13.
//    The module-scope store already value-copied; this path did not.
//
// 3. MEMBER WRITES INTO AN UNPACKED-STRUCT ELEMENT WERE DROPPED. `new[]'
//    leaves an object-backed value element nil, so `arr[i].f = v' stored
//    through a null handle. A signal-backed container had its element
//    materialized on first access from the functor's declared type; a
//    container held in a class property has no signal to ask, so the
//    container now carries the element class itself.
//
// Pre-fix, part 1 printed `0' where 1 is required and aborted on the
// index-1 cells; part 2 printed the last value in every element; part 3
// read back zero.

class leaf;
  int f;
endclass

typedef struct { bit [7:0] f; int g; } S;

class holder;
  leaf d[];        // dynamic array of handles
  leaf q[$];       // queue of handles
  leaf ai[int];    // associative, integer key
  leaf as[string]; // associative, string key
  leaf k[2];       // fixed-size array of handles (the control)

  S sd[];          // dynamic array of unpacked structs
  S sa[int];       // associative array of unpacked structs
  S sk[4];         // fixed-size array of unpacked structs

  function new();
    d = new[2];
    q.push_back(null);
    q.push_back(null);
    ai[0] = null;
    ai[1] = null;
    as["a"] = null;
    as["b"] = null;
    sd = new[4];
  endfunction

  // The lazy-allocation idiom, exercised from inside the class too.
  function void fill_d();
    foreach (d[i]) if (d[i] == null) begin
      d[i] = new();
      d[i].f = i + 1;
    end
  endfunction
endclass

module main;

  holder h;
  leaf   m[];            // module-scope control
  S      ms[];           // module-scope control
  S      t;
  int    fails = 0;

  initial begin
    h = new();
    m = new[2];
    ms = new[4];

    // ---- part 1: null tests on container-property elements ----
    if (!(m[0] == null)) begin
      fails++; $display("FAILED -- module darray m[0]==null read 0; the control is broken");
    end

    if (!(h.d[0] == null)) begin
      fails++; $display("FAILED -- darray property d[0]==null read 0 (element is null)");
    end
    if (!(h.d[1] == null)) begin
      fails++; $display("FAILED -- darray property d[1]==null read 0 (element is null)");
    end
    if (h.d[0] != null) begin
      fails++; $display("FAILED -- darray property d[0]!=null read 1 (element is null)");
    end
    if (!(h.q[0] == null) || !(h.q[1] == null)) begin
      fails++; $display("FAILED -- queue property q[i]==null read 0 (elements are null)");
    end
    if (!(h.ai[0] == null) || !(h.ai[1] == null)) begin
      fails++; $display("FAILED -- assoc(int) property ai[i]==null read 0 (elements are null)");
    end
    if (!(h.as["a"] == null) || !(h.as["b"] == null)) begin
      fails++; $display("FAILED -- assoc(string) property as[k]==null read 0 (elements are null)");
    end
    if (!(h.k[0] == null) || !(h.k[1] == null)) begin
      fails++; $display("FAILED -- fixed array property k[i]==null read 0 (elements are null)");
    end

    // A non-null element must still compare non-null.
    h.d[1] = new();
    h.d[1].f = 7;
    if (h.d[1] == null) begin
      fails++; $display("FAILED -- darray property d[1]==null read 1 after allocation");
    end
    if (h.d[1].f != 7) begin
      fails++; $display("FAILED -- darray property d[1].f=%0d (want 7)", h.d[1].f);
    end

    // ---- the lazy-allocation idiom, from inside the class ----
    h = new();
    h.fill_d();
    if (h.d[0] == null || h.d[1] == null) begin
      fails++; $display("FAILED -- lazy allocation left an element null");
    end else if (h.d[0].f != 1 || h.d[1].f != 2) begin
      fails++; $display("FAILED -- lazy allocation values %0d %0d (want 1 2)",
                        h.d[0].f, h.d[1].f);
    end

    // ---- part 2: unpacked-struct elements are values, not references ----
    for (int i = 0; i < 4; i++) begin
      t.f = i + 10;
      t.g = i + 100;
      ms[i]   = t;
      h.sd[i] = t;
      h.sa[i] = t;
      h.sk[i] = t;
    end

    for (int i = 0; i < 4; i++) begin
      if (ms[i].f != i + 10) begin
        fails++; $display("FAILED -- module darray ms[%0d].f=%0d (want %0d); the control is broken",
                          i, ms[i].f, i + 10);
      end
      if (h.sd[i].f != i + 10 || h.sd[i].g != i + 100) begin
        fails++; $display("FAILED -- struct darray property sd[%0d]=%0d/%0d (want %0d/%0d)",
                          i, h.sd[i].f, h.sd[i].g, i + 10, i + 100);
      end
      if (h.sa[i].f != i + 10 || h.sa[i].g != i + 100) begin
        fails++; $display("FAILED -- struct assoc property sa[%0d]=%0d/%0d (want %0d/%0d)",
                          i, h.sa[i].f, h.sa[i].g, i + 10, i + 100);
      end
      if (h.sk[i].f != i + 10 || h.sk[i].g != i + 100) begin
        fails++; $display("FAILED -- struct fixed-array property sk[%0d]=%0d/%0d (want %0d/%0d)",
                          i, h.sk[i].f, h.sk[i].g, i + 10, i + 100);
      end
    end

    // Mutating the source after the stores must not disturb any element.
    t.f = 99;
    t.g = 99;
    if (h.sd[3].f != 13 || h.sa[3].f != 13 || h.sk[3].f != 13) begin
      fails++;
      $display("FAILED -- an element aliased the source struct: sd=%0d sa=%0d sk=%0d (want 13 13 13)",
               h.sd[3].f, h.sa[3].f, h.sk[3].f);
    end

    // ---- part 3: a member write into an unpacked-struct ELEMENT ----
    // `new[]' leaves an object-backed value element nil, so the member
    // write stored through a null handle and was silently dropped for a
    // container held in a class property. A signal-backed container got
    // the element materialized from its functor's declared type; a
    // property-held one had no signal to ask, so the container now
    // carries the element class itself.
    begin
      automatic holder h2 = new();
      foreach (h2.sd[i]) h2.sd[i].f = i + 40;
      for (int i = 0; i < 4; i++)
        if (h2.sd[i].f != i + 40) begin
          fails++;
          $display("FAILED -- member write into struct element sd[%0d].f=%0d (want %0d)",
                   i, h2.sd[i].f, i + 40);
        end
      h2.sd[2].f += 5;
      if (h2.sd[2].f != 47) begin
        fails++;
        $display("FAILED -- compound member write on struct element sd[2].f=%0d (want 47)",
                 h2.sd[2].f);
      end
      h2.sd[2].f <= 60;
      #1;
      if (h2.sd[2].f != 60) begin
        fails++;
        $display("FAILED -- nonblocking member write on struct element sd[2].f=%0d (want 60)",
                 h2.sd[2].f);
      end
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
