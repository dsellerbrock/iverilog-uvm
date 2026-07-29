// IEEE 1800-2017 6.23: the type() operator.
//
// Covers:
//  - type(expr)==type(expr) / != for same/different width and signing
//  - typedef alias matching (6.22.1)
//  - type(a)==type(int) (atom vs equivalent packed-vector spelling --
//    this fork treats them as matching; see sv_param_type_identity1.v
//    for the specialization-identity pin backing that decision)
//  - type() naming a type directly in variable-declaration and typedef
//    position (`var type(...) x;`, `typedef type(...) t;`), checked via
//    $bits()
//  - generate-if selecting a branch by type equality
//  - type(expr) does NOT evaluate expr (a side-effecting function call
//    inside type() must not run)
//  - enum and class-handle operands (supported); struct/union operands
//    are NOT supported by this fork (see tests/negative/
//    type_operator_struct_compare.sv) and so are not exercised here.
//
// Everything below is gathered under ONE top module with a single
// shared `failed` flag and a single final "PASSED" line -- the ivtest
// harness (run_ivl.py) only checks for the presence of a "PASSED" line
// anywhere in stdout, so splitting the checks across independent
// uninstantiated top modules (each printing its own PASSED) would let
// one module's failure hide behind another module's success.

`define check(expr, val) \
  if ((expr) !== (val)) begin \
    $display("FAILED: %s, expected %0d, got %0d", `"expr`", val, expr); \
    failed = 1'b1; \
  end

module counter_bump;
  int m_count = 0;
  function automatic int bump();
    m_count = m_count + 1;
    return m_count;
  endfunction
endmodule

module gen_select #(parameter type T = int) ();
  // Generate-if selecting a branch by type equality (IEEE 1800-2017 6.23).
  if (type(T) == type(int)) begin : g_sel
    localparam int SELECTED = 1;
  end else begin : g_sel
    localparam int SELECTED = 0;
  end
endmodule

module test;
  bit failed = 1'b0;

  int a;
  int a2;
  bit signed [31:0] b;        // same shape as `int`: matches
  bit [31:0] c;                // unsigned: does not match `int`
  bit signed [15:0] narrow;    // narrower: does not match

  typedef int my_int_t;
  my_int_t d;                  // typedef alias of int: matches

  typedef enum { RED, GREEN, BLUE } color_e;
  color_e col1, col2;
  typedef color_e color_alias_t;
  color_alias_t col3;

  class Foo;
    int x;
  endclass
  class Bar;
    int y;
  endclass
  Foo foo1, foo2;
  Bar bar1;

  counter_bump u_bump();

  gen_select #(int)  u_gs_int();
  gen_select #(real) u_gs_real();

  // type() naming a type directly, in variable-declaration and typedef
  // position. Grammar note: `var type(...) name;` is supported; the
  // bare (non-var) spelling `type(...) name;` is NOT -- see the
  // block_item_decl comment in parse.y for why (every attempted
  // grammar placement of that one shape perturbed an existing
  // reduce/reduce conflict state by +1; `var` is required instead of
  // accepting that cost).
  var type(a) decl_from_a;         // variable declaration naming type(a)
  typedef type(b) decl_typedef_t;  // typedef naming type(b)
  decl_typedef_t decl_from_typedef;

  initial begin
    // -- same/different widths and signing --------------------------
    `check(type(a) == type(a2), 1'b1)   // identical declared type
    `check(type(a) == type(b),  1'b1)   // int vs bit signed[31:0]: matches
    `check(type(a) == type(c),  1'b0)   // int vs bit[31:0] unsigned: no match
    `check(type(a) != type(c),  1'b1)
    `check(type(a) == type(narrow), 1'b0) // width differs: no match
    `check(type(b) == type(narrow), 1'b0)

    // -- typedef alias matching (6.22.1) ------------------------------
    `check(type(a) == type(d), 1'b1)   // my_int_t is a typedef of int

    // -- atom vs equivalent packed-vector spelling --------------------
    `check(type(a) == type(int), 1'b1)
    `check(type(c) == type(int), 1'b0)

    // -- === / !== (case equality forms) also supported --------------
    `check(type(a) === type(b), 1'b1)
    `check(type(a) !== type(c), 1'b1)

    // -- enum operands -------------------------------------------------
    `check(type(col1) == type(col2), 1'b1)     // same enum type
    `check(type(col1) == type(col3), 1'b1)     // typedef alias of the enum

    // -- class-handle operands -----------------------------------------
    `check(type(foo1) == type(foo2), 1'b1)     // same class
    `check(type(foo1) == type(bar1), 1'b0)     // unrelated classes

    // -- type(expr) must not evaluate expr (no side effects) ----------
    `check(u_bump.m_count, 0)
    `check(type(u_bump.bump()) == type(int), 1'b1)
    `check(u_bump.m_count, 0)   // still zero: bump() was never called

    // -- generate-if selecting per type equality ----------------------
    `check(u_gs_int.g_sel.SELECTED,  1)
    `check(u_gs_real.g_sel.SELECTED, 0)

    // -- type() in variable-declaration / typedef position ------------
    decl_from_a = 32'hDEAD_BEEF;
    decl_from_typedef = 32'hFEED_FACE;
    `check($bits(decl_from_a), 32)
    `check($bits(decl_from_typedef), 32)
    `check(decl_from_a, 32'hDEAD_BEEF)
    `check(decl_from_typedef, 32'hFEED_FACE)

    if (!failed) $display("PASSED");
  end
endmodule
