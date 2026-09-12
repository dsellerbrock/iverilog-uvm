// L40: a REAL, executing specialization of a parameterized class assigning
// a class-handle-typed value (via its type parameter T) to a `string`
// local variable, inside the class's own method body, used to silently
// produce "" with ZERO diagnostic (netmisc.cc's class_rval_degrade_ok used
// the coarse `in_class_scope' check -- true for ANY code lexically inside
// ANY class body -- with no carve-out for a REAL specialized instance).
// This is a real, executing method on a genuinely specialized class
// (container#(obj_c)), not a dead generic-template pass, so it must be a
// hard error like any other class-handle-to-string assignment
// (IEEE 1800-2017/2023 8.4). See sv_class_handle_string_seed_ok.v for the
// sibling case that must stay silent, and
// sv_class_handle_string_forward_ref_ok.v for the unrelated forward-
// reference-collapse case that must ALSO stay silent (the one an earlier,
// reverted attempt at this fix broke).
module test;
  class container #(type T = int);
    T val;
    function string describe();
      string s;
      s = val;
      return s;
    endfunction
  endclass

  class obj_c;
    string name;
  endclass

  container #(obj_c) c;
  obj_c o;
  string s;

  initial begin
    c = new;
    o = new;
    o.name = "hi";
    c.val = o;
    s = c.describe();
    $display("s=%s", s);
  end
endmodule
