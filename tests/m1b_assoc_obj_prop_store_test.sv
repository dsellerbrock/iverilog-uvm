// Finding 6 (M1B / Phase 4): assignment to a class-object property through
// an associative-array element, `amap[key].prop = v`. The l-value base
// object was loaded positionally (%load/dar/obj with the key as an index)
// instead of by key, so for any key != position it loaded a null/wrong
// element and the store was silently dropped. Now the l-value base loads
// by key (matching the read path), so the store lands. Queue and dynamic-
// array element property stores (which already worked) are checked too, as
// is a string-keyed assoc and a compound assignment through the element.
module m1b_assoc_obj_prop_store_test;
  class C; int prop; endclass

  C amap[int];
  C smap[string];
  C aq[$];
  C ad[];
  C tmp;
  int errors = 0;

  task chk(string nm, int got, int exp);
    if (got !== exp) begin $display("FAIL %s: got %0d exp %0d", nm, got, exp); errors++; end
  endtask

  initial begin
    amap[5]  = new; amap[5].prop  = 42;         // int-keyed assoc element
    smap["k"]= new; smap["k"].prop= 7;
    smap["k"].prop += 5;                         // compound through assoc element
    tmp = new; aq.push_back(tmp); aq[0].prop = 43;
    ad = new[1]; ad[0] = new; ad[0].prop = 44;

    chk("amap[5]",   amap[5].prop,   42);
    chk("smap[k]",   smap["k"].prop, 12);
    chk("aq[0]",     aq[0].prop,     43);
    chk("ad[0]",     ad[0].prop,     44);

    // The stored object must be the SAME one the map holds (reference).
    tmp = amap[5];
    chk("shared-ref", tmp.prop, 42);

    if (errors == 0) $display("PASS m1b_assoc_obj_prop_store_test");
    else             $display("FAIL m1b_assoc_obj_prop_store_test (%0d errors)", errors);
    $finish;
  end
endmodule
