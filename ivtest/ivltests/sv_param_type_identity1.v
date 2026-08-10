// Campaign 4 (type identity) regression: pins the parameterized-class
// SPECIALIZATION-IDENTITY behavior this fork's elaborate_specialized_class_type()
// cache (elab_scope.cc) already implements -- i.e. when two type-parameter
// arguments are close enough that the cache treats them as "the same
// specialization" (and so shares one netclass_t / one set of static
// locals) versus "different specializations" (separate statics).
//
// This is the SAME structural predicate the `type()` operator's equality
// fold (IEEE 1800-2017 6.23) reuses -- see type_operator_kind_supported_
// and the type_operator_types_match_ comment in elab_expr.cc. This file
// pins the specialization-cache side directly (not via `type()`) so a
// future change to either mechanism shows up as a visible regression
// here, independent of the `type()` grammar/elaboration work.
//
// typedef int my_int_t;  // (used below)
//
// IEEE 1800-2017 6.22.1 "matching types" rule 1 restricts matching to
// "the same predefined integer ... type" by NAME -- read strictly, an
// atom type (`int`) and an equivalent-width packed vector spelling
// (`bit signed [31:0]`) are arguably NOT the same predefined type name,
// so should NOT match. However this fork's specialization cache keys
// classes structurally (by the ELABORATED ivl_type_t's base_type +
// packed width + signedness, effectively -- see
// append_cache_ivl_type_key_/cached_type_dump_ in elab_scope.cc), which
// cannot distinguish "int" from "bit signed [31:0]" once both have been
// lowered to the same netvector_t shape. Accellera Mantis 1447 discusses
// exactly this ambiguity with no single agreed resolution across tools.
// This is a DELIBERATE, documented fork choice (not an oversight): pin
// it here so any future change to that choice is a visible, reviewed
// decision rather than a silent drift.

class box #(type T = int);
  typedef box#(T) this_type;

  static function this_type get();
    static this_type m_inst;
    if (m_inst == null) m_inst = new;
    return m_inst;
  endfunction
endclass

// The method-local typedef deliberately shadows the enclosing class type
// formal.  The implicit named actual is represented as a PEIdent, so cache-key
// canonicalization must retain its lexical lookup scope instead of resolving
// it as lexical_shadow_probe::T.
class lexical_shadow_probe #(type T = byte);
  static function bit check();
    check = 1'b1;

    begin : local_scope
      typedef int T;
      box#(.T) implicit_named;
      box#(.T(int)) explicit_named;
      box#(int) positional;
      box#(int) casted;

      implicit_named = box#(.T)::get();
      explicit_named = box#(.T(int))::get();
      positional = box#(int)::get();

      if (implicit_named == null || explicit_named == null ||
          positional == null) begin
        $display("FAILED: lexical-shadow specialization returned null");
        check = 1'b0;
      end else if (implicit_named !== explicit_named ||
                   implicit_named !== positional) begin
        $display("FAILED: implicit named lexical T did not canonicalize to explicit int forms");
        check = 1'b0;
      end

      if (!$cast(casted, implicit_named) || casted !== positional) begin
        $display("FAILED: lexical-shadow specialization runtime type identity mismatch");
        check = 1'b0;
      end
    end
  endfunction
endclass

class value_box #(int N = 0);
  typedef value_box#(N) this_type;
  logic [N:0] value;

  static function this_type get();
    static this_type m_inst;
    if (m_inst == null) m_inst = new;
    return m_inst;
  endfunction
endclass

class value_lexical_probe;
  localparam int P = 3;

  static function bit check();
    value_box#(.N(P)) via_localparam;
    value_box#(.N(3)) via_literal;

    check = 1'b1;
    via_localparam = value_box#(.N(P))::get();
    via_literal = value_box#(.N(3))::get();

    if ($bits(via_localparam.value) != 4 ||
        $bits(via_literal.value) != 4) begin
      $display("FAILED: value-parameter lexical P resolved to wrong value");
      check = 1'b0;
    end else if (type(via_localparam) != type(via_literal)) begin
      $display("FAILED: lexical P and literal value parameter types differ");
      check = 1'b0;
    end else if (via_localparam == null || via_literal == null ||
                 via_localparam !== via_literal) begin
      $display("FAILED: lexical P and literal value parameters did not share identity");
      check = 1'b0;
    end
  endfunction
endclass

class untyped_value_box #(parameter N = 0);
  typedef untyped_value_box#(N) this_type;
  logic [$bits(N)-1:0] value;

  static function this_type get();
    static this_type m_inst;
    if (m_inst == null) m_inst = new;
    return m_inst;
  endfunction
endclass

class untyped_value_width_probe;
  static function bit check();
    untyped_value_box#(8'd3) narrow;
    untyped_value_box#(32'd3) wide;

    check = 1'b1;
    narrow = untyped_value_box#(8'd3)::get();
    wide = untyped_value_box#(32'd3)::get();

    if ($bits(narrow.value) != 8 || $bits(wide.value) != 32) begin
      $display("FAILED: untyped value-parameter widths were not preserved");
      check = 1'b0;
    end else if (type(narrow) == type(wide)) begin
      $display("FAILED: width-distinct untyped values shared one class type");
      check = 1'b0;
    end else if (narrow == null || wide == null || narrow === wide) begin
      $display("FAILED: width-distinct untyped values shared one singleton");
      check = 1'b0;
    end
  endfunction
endclass

// This later compilation-unit type name must not displace the nearer class
// localparam when value_lexical_probe's method elaborates .N(P).
typedef logic [7:0] P;

module test;
  typedef int my_int_t;
  bit failed = 1'b0;

  initial begin

    // C#(int) vs C#(typedef int): a typedef of a matching type is a
    // matching type (IEEE 1800-2017 6.22.1) -- must share statics.
    begin
      box#(int) a, b;
      a = box#(int)::get();
      b = box#(my_int_t)::get();
      if (a == null || b == null) begin
        $display("FAILED: box#(int)/box#(my_int_t) singleton returned null");
        failed = 1'b1;
      end else if (a !== b) begin
        $display("FAILED: box#(int) vs box#(typedef int) did not share statics");
        failed = 1'b1;
      end
    end

    // C#(bit[31:0] unsigned) is distinct from C#(int) (int is signed).
    begin
      box#(int) a;
      box#(bit [31:0]) c;
      a = box#(int)::get();
      c = box#(bit [31:0])::get();
      if (a == null || c == null) begin
        $display("FAILED: box#(int)/box#(bit[31:0]) singleton returned null");
        failed = 1'b1;
      end else if (a === c) begin
        $display("FAILED: box#(int) and box#(bit[31:0] unsigned) unexpectedly shared statics");
        failed = 1'b1;
      end
    end

    // C#(bit signed[15:0]) is distinct from C#(int) (width differs: 16 vs 32).
    begin
      box#(int) a;
      box#(bit signed [15:0]) d;
      a = box#(int)::get();
      d = box#(bit signed [15:0])::get();
      if (a == null || d == null) begin
        $display("FAILED: box#(int)/box#(bit signed[15:0]) singleton returned null");
        failed = 1'b1;
      end else if (a === d) begin
        $display("FAILED: box#(int) and box#(bit signed[15:0]) unexpectedly shared statics");
        failed = 1'b1;
      end
    end

    // C#(int) vs C#(bit signed[31:0]): SAME under this fork's current
    // matching predicate -- see the file header comment. Pinned here
    // deliberately; if this ever changes, update this comment too.
    begin
      box#(int) a;
      box#(bit signed [31:0]) e;
      a = box#(int)::get();
      e = box#(bit signed [31:0])::get();
      if (a == null || e == null) begin
        $display("FAILED: box#(int)/box#(bit signed[31:0]) singleton returned null");
        failed = 1'b1;
      end else if (a !== e) begin
        $display("FAILED: box#(int) vs box#(bit signed[31:0]) did NOT share statics (current-behavior pin broke)");
        failed = 1'b1;
      end
    end

    // The outer formal is byte, while the nearer typedef is int.  A cache key
    // that drops the method/block lexical scope will select box#(byte) here.
    if (!lexical_shadow_probe#(byte)::check())
      failed = 1'b1;

    if (!value_lexical_probe::check())
      failed = 1'b1;

    if (!untyped_value_width_probe::check())
      failed = 1'b1;

    if (!failed) $display("PASSED");
  end
endmodule
