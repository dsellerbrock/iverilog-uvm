// IEEE 1800-2017/2023 13.4.2: a call to a subroutine that takes no arguments
// may omit its parentheses.
//
// This is the UNQUALIFIED spelling -- a bare identifier, with no receiver --
// which is a different elaboration path from the qualified `obj.m' form
// covered by sv_class_parenless_method_via_property.
//
// OpenTitan's xbar_base_vseq.sv:68-70 relies on it:
//
//     `uvm_info(get_full_name, $sformatf(...), UVM_HIGH)
//
// `get_full_name' is a zero-argument method INHERITED from uvm_object. As a
// bare name inside a class method it first goes through ordinary signal
// binding, which fails; before this fix the reference then elaborated to
// nothing, so the read yielded an empty string. That was SILENT and WRONG,
// not merely unsupported: the diagnostic was only a compile-progress
// "Unable to bind wire/reg/memory `get_full_name'" warning, and the
// simulation ran on with a blank name.
//
// Resolution happens only AFTER signal binding fails, so a real variable of
// the same name must still win -- the `shadow' case below pins that.
//
// slang 11.0.448 accepts every form below under both editions.

class base;
  int n;
  function new(int v = 3); n = v; endfunction
  function string get_full_name(); return "base.inst"; endfunction
  function int    get_id();        return n * 2;       endfunction
  static function int st_zero();   return 5;           endfunction
  function int    one_arg(int a);  return a + 1;       endfunction
endclass

class child extends base;
  function new(int v = 3); super.new(v); endfunction

  // Inherited, unqualified, paren-less. This is the xbar_base_vseq shape.
  function string inherited_string(); return get_full_name; endfunction
  function int    inherited_int();    return get_id;        endfunction

  // A static method has no implicit `this' port, so it reaches the
  // zero-argument test with a different port count than an instance method.
  function int    static_call();      return st_zero;       endfunction

  // Explicit parentheses must keep working.
  function string with_parens();      return get_full_name(); endfunction

  // A local variable whose name matches a method of this class must still
  // read the variable: ordinary binding succeeds, so the method fallback
  // must never be consulted.
  function int shadow();
    int get_id;
    get_id = 42;
    return get_id;
  endfunction

  // Calling a one-argument method still needs its argument; the paren-less
  // form is only legal for zero-argument subroutines.
  function int one_arg_ok(); return one_arg(4); endfunction
endclass

module main;

  int errors = 0;

  task automatic chk_i(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAILED: %s got %0d want %0d", what, got, exp);
      errors += 1;
    end
  endtask

  task automatic chk_s(string what, string got, string exp);
    if (got != exp) begin
      $display("FAILED: %s got \"%s\" want \"%s\"", what, got, exp);
      errors += 1;
    end
  endtask

  child c;

  initial begin
    c = new(3);

    // The regression: unqualified paren-less call to an inherited method.
    chk_s("inherited_string", c.inherited_string(), "base.inst");
    chk_i("inherited_int",    c.inherited_int(),    6);

    // Static method, same spelling, no implicit `this'.
    chk_i("static_call",      c.static_call(),      5);

    // Explicit parentheses unaffected.
    chk_s("with_parens",      c.with_parens(),      "base.inst");

    // A same-named local variable still wins over the method.
    chk_i("shadow",           c.shadow(),           42);

    // A method that takes an argument is unaffected.
    chk_i("one_arg_ok",       c.one_arg_ok(),       5);

    // Qualified forms, for contrast with the unqualified path above.
    chk_s("c.get_full_name",  c.get_full_name,      "base.inst");
    chk_i("c.get_id",         c.get_id,             6);

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d error(s)", errors);
  end

endmodule
