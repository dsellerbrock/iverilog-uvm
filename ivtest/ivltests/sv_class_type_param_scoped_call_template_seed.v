// IEEE 1800-2017/2023 8.25: "A generic class is not a type; only a concrete
// specialization represents a type."
//
// The body of an unspecialized parameterized class is a template seed: it is
// elaborated with the declared default type parameters and never executed. A
// static call through a type parameter that binds to no class in that body
// has nothing to check yet -- each real specialization checks it again.
//
// This is the shape UVM's uvm_registry.svh writes. uvm_component_registry
// #(T,Tname) defines
//     common_type = uvm_registry_common#(this_type, ..., T, Tname)
// and uvm_registry_common #(type Tregistry=int, type Tcreator=int, ...) calls
// Tregistry::get() -- back into the enclosing specialization. Under the
// generic body's own `int' defaults that reads as `int::get()', which is
// meaningless until specialized. Icarus rejected the whole construct on that
// basis; slang 11.0.448 accepts it under --std 1800-2017 and 1800-2023.
//
// The residual negatives are pinned separately and must STAY loud:
//   sv_class_type_param_bound_missing_fail  -- bound to a class lacking it
//   sv_class_type_param_default_spec_fail   -- explicit default spec C#()

module main;

  int errors = 0;

  task automatic chk(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAILED: %s got %0d want %0d", what, got, exp);
      errors += 1;
    end
  endtask

  // --- the mutually recursive registry cycle -------------------------------
  // common#(Treg,...) calls back into the registry specialization that named
  // it, so elaborating either requires the other to already be findable.


  class common #(type Treg = int, type Tcreated = int, string Tname = "?");
    typedef common #(Treg, Tcreated, Tname) this_type;

    static function string type_name(); return Tname; endfunction

    static function this_type get();
      static this_type m_inst;
      if (m_inst == null) m_inst = new();
      return m_inst;
    endfunction

    // Static call through a type parameter bound to the ENCLOSING
    // specialization. Under the generic defaults Treg is `int', which has no
    // tag() -- that is the template seed, not an error.
    static function int poke(); return Treg::tag(); endfunction
  endclass

  class registry #(type T = int, string Tname = "?");
    typedef registry #(T, Tname) this_type;
    typedef common #(this_type, T, Tname) common_type;

    static function int tag(); return 33; endfunction
    static function string type_name(); return common_type::type_name(); endfunction

    static function this_type get();
      static this_type m_inst;
      if (m_inst == null) m_inst = new();
      return m_inst;
    endfunction

    // registry -> common#(registry) -> Treg::tag() -> back to registry
    static function int roundtrip(); return common_type::poke(); endfunction
  endclass

  // --- control: a type parameter whose DEFAULT is already a class ----------
  // The generic body is elaboratable here, so this path never depended on the
  // template-seed rule. It must keep working unchanged.

  class has_tag;
    static function int tag(); return 99; endfunction
  endclass

  class ctrl #(type Treg = has_tag);
    static function int poke(); return Treg::tag(); endfunction
  endclass

  initial begin
    // Values, not merely compilation: the specialization must still execute.
    chk("tag",            registry#(int,"a")::tag(),        33);
    chk("roundtrip",      registry#(int,"a")::roundtrip(),  33);
    chk("ctrl default",   ctrl#()::poke(),                  99);
    chk("ctrl explicit",  ctrl#(has_tag)::poke(),           99);

    if (registry#(int,"a")::type_name() != "a") begin
      $display("FAILED: type_name got %s want a", registry#(int,"a")::type_name());
      errors += 1;
    end

    // Two distinct specializations of the same generic class stay distinct
    // and both resolve (8.25: each specialization is its own type).
    if (registry#(int,"a")::type_name() == registry#(int,"b")::type_name()) begin
      $display("FAILED: distinct specializations collapsed");
      errors += 1;
    end

    if (registry#(int,"a")::get() == null) begin
      $display("FAILED: get() returned null");
      errors += 1;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d error(s)", errors);
  end

endmodule
