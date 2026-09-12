// L40 sibling of sv_class_handle_string_specialized_fail.v: `container`'s
// OWN declared default type parameter is a class (base_c). Icarus
// elaborates a parameterized class's generic body once, seeded with its
// own declared defaults (IEEE 1800-2017/2023 8.25, "a generic class is not
// a type") -- that seed pass sees `val' as base_c-typed, so `s = val;'
// inside `describe()' looks like an illegal class-handle-to-string
// assignment. But nothing in this design ever specializes `container' with
// a class type: the only real, executing specialization is
// `container#(int)', and `describe()' is never even called. The seed pass
// is dead code and must stay silent. Deliberately does not call
// describe() or read `val' back as a string -- that would additionally
// exercise an unrelated, separately-tracked runtime gap
// (vvp/class_type.cc:536 class_property_t::get_string on an integral
// property; see DISCOVERED_DEBT.md).
module test;
  class base_c;
    int dummy;
  endclass

  class container #(type T = base_c);
    T val;
    function string describe();
      string s;
      s = val;
      return s;
    endfunction
  endclass

  container #(int) c;

  initial begin
    c = new;
    c.val = 42;
    $display("PASSED");
  end
endmodule
