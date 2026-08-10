// A static random variable has one rand_mode state per exact declaring class
// specialization. The state is shared by base and sibling-derived objects,
// while distinct parameter specializations remain isolated. An omitted
// default and its explicit value denote the same specialization.
class mode_base #(int TAG = 0);
  static rand int shared;
  static int class_scope_cookie = TAG;
endclass

class mode_left extends mode_base#(1);
endclass

class mode_right extends mode_base#(1);
endclass

// A specialization created while walking a generic master must retain its
// value-parameter forwarding provenance. In particular, the provisional M in
// forwarding_mid#(M) must not be cached as a concrete forwarding_inner#(0).
class forwarding_inner #(int N = 0);
  bit [N:0] payload;

  function int tag();
    return N;
  endfunction
endclass

class forwarding_mid #(int M = 0);
  forwarding_inner#(M) inner;
endclass

class forwarding_outer #(int M = 0);
  forwarding_mid#(M) mid;
endclass

module test;
  initial begin
    mode_base bare_obj;
    mode_base#() default_obj;
    mode_base#(0) explicit_default_obj;
    mode_base#(.TAG(0)) named_default_obj;
    mode_base#(1) tag1_obj;
    mode_base#(.TAG(1)) named_tag1_obj;
    mode_base#(2) tag2_obj;
    mode_left left_obj;
    mode_right right_obj;
    forwarding_outer#(0) forwarded_default;
    forwarding_outer#(1) forwarded_nondefault;
    forwarding_inner#(0) explicit_inner_default;
    forwarding_inner#(1) explicit_inner_nondefault;

    bare_obj = new;
    default_obj = new;
    explicit_default_obj = new;
    named_default_obj = new;
    tag1_obj = new;
    named_tag1_obj = new;
    tag2_obj = new;
    left_obj = new;
    right_obj = new;
    forwarded_default = new;
    forwarded_default.mid = new;
    forwarded_default.mid.inner = new;
    forwarded_nondefault = new;
    forwarded_nondefault.mid = new;
    forwarded_nondefault.mid.inner = new;
    explicit_inner_default = new;
    explicit_inner_nondefault = new;

    if (type(forwarded_default.mid.inner) != type(explicit_inner_default)
        || type(forwarded_nondefault.mid.inner) != type(explicit_inner_nondefault)
        || type(forwarded_default.mid.inner) == type(forwarded_nondefault.mid.inner)
        || $bits(forwarded_default.mid.inner.payload) != 1
        || $bits(forwarded_nondefault.mid.inner.payload) != 2
        || forwarded_default.mid.inner.tag() != 0
        || forwarded_nondefault.mid.inner.tag() != 1)
      $fatal(1, "generic value-parameter forwarding lost specialization identity");

    if (type(bare_obj) != type(default_obj)
        || type(default_obj) != type(explicit_default_obj)
        || type(explicit_default_obj) != type(named_default_obj))
      $fatal(1, "bare/default/named/positional types did not canonicalize");
    if (type(tag1_obj) != type(named_tag1_obj)
        || type(default_obj) == type(tag1_obj)
        || type(tag1_obj) == type(tag2_obj))
      $fatal(1, "nondefault specialization type identity collapsed");

    mode_base#(.TAG(0))::class_scope_cookie = 41;
    if (mode_base#()::class_scope_cookie !== 41
        || mode_base#(0)::class_scope_cookie !== 41
        || mode_base#(1)::class_scope_cookie !== 1
        || mode_base#(2)::class_scope_cookie !== 2)
      $fatal(1, "default static NetNet aliasing or nondefault isolation failed");

    if (!bare_obj.shared.rand_mode()
        || !default_obj.shared.rand_mode()
        || !tag1_obj.shared.rand_mode()
        || !tag2_obj.shared.rand_mode())
      $fatal(1, "static rand_mode did not start enabled");

    bare_obj.shared.rand_mode(0);
    if (default_obj.shared.rand_mode() !== 0
        || explicit_default_obj.shared.rand_mode() !== 0
        || named_default_obj.shared.rand_mode() !== 0)
      $fatal(1, "default and explicit-default specializations diverged");
    if (tag1_obj.shared.rand_mode() !== 1
        || tag2_obj.shared.rand_mode() !== 1)
      $fatal(1, "one specialization changed another specialization");
    named_default_obj.shared.rand_mode(1);

    left_obj.shared.rand_mode(0);
    if (right_obj.shared.rand_mode() !== 0
        || tag1_obj.shared.rand_mode() !== 0
        || named_tag1_obj.shared.rand_mode() !== 0)
      $fatal(1, "base and sibling-derived modes did not share");
    if (bare_obj.shared.rand_mode() !== 1
        || default_obj.shared.rand_mode() !== 1
        || tag2_obj.shared.rand_mode() !== 1)
      $fatal(1, "derived mode escaped its exact base specialization");
    tag1_obj.shared.rand_mode(1);
    if (left_obj.shared.rand_mode() !== 1
        || right_obj.shared.rand_mode() !== 1)
      $fatal(1, "base re-enable did not reach derived objects");

    $display("PASSED");
  end
endmodule
