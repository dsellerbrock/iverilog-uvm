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

    if (!failed) $display("PASSED");
  end
endmodule
