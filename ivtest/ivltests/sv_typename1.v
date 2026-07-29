// $typename() (IEEE 1800-2017 20.6.1) returned wrong strings for nearly
// every type. It was implemented purely as a run-time VPI system
// function (vpi/sys_sv_class.cc) that inspected vpi_get(vpiType, arg)
// against a handful of cases and otherwise fell through to a "logic"
// default -- so `int i; $typename(i)` returned "logic", `logic [7:0] v;
// $typename(v)` returned "reg", an unpacked array or an enum both
// returned "logic", and so on for nearly every declared type.
//
// A SystemVerilog expression's type is always statically known, so
// $typename() is now folded to a string constant at elaboration time
// (elab_expr.cc, PECallFunction::elaborate_sfunc_, name=="$typename"),
// built by walking the argument's actual ivl_type_t. The run-time VPI
// function remains only as a fallback for the one shape that cannot be
// folded away (a bare `$typename(x);` task-call statement, whose result
// is discarded and therefore never observed).
//
// Implementation-specific format choices, documented here because the
// LRM does not fully specify them:
//  - Icarus does not track whether an enum or struct type came from a
//    typedef (netenum_t/netstruct_t carry no name of their own), so
//    both typedef'd and anonymous enums/structs always print the LRM's
//    anonymous-enum-style structural expansion; for enums, the
//    argument's own declared name is appended afterward, matching the
//    LRM 20.6.1 example's trailing "...}e1".
//  - A parameterized class specialization prints only the base class
//    name (elaboration does not thread actual parameter values into a
//    specialization's name), so `Container#(byte)` and
//    `Container#(int)` both print as "Container".
//  - An associative array whose index type could not be recovered at
//    the point it was elaborated falls back to "$[int]" rather than
//    dropping the "$[...]" suffix.

module main;

  int fails = 0;

  task chk(string what, string got, string want);
    if (got != want) begin
      fails++;
      $display("FAILED -- %s: got `%s` want `%s`", what, got, want);
    end
  endtask

  // ---- 1. Atoms (signed and unsigned) ----
  int          a_int;
  int unsigned a_int_u;
  integer      a_integer;
  integer unsigned a_integer_u;
  bit          a_bit;
  bit unsigned a_bit_u;
  bit signed   a_bit_s;
  byte         a_byte;
  byte unsigned a_byte_u;
  shortint     a_shortint;
  shortint unsigned a_shortint_u;
  longint      a_longint;
  longint unsigned a_longint_u;
  time         a_time;
  real         a_real;
  string       a_string;
  chandle      a_chandle;

  // ---- 2. Packed vectors ----
  logic [7:0]      v_logic8;
  bit [3:0]        v_bit4;
  logic signed [15:8] v_logic_off;

  // ---- 3. Enums ----
  typedef enum {ENUM_A, ENUM_B} e_t;
  e_t          en_typedef;
  enum {ENUM_X, ENUM_Y, ENUM_Z} en_anon;
  typedef enum bit [1:0] {RED, GREEN, BLUE} color_t;
  color_t      en_narrow;

  // ---- 4. Unpacked/dynamic/associative/queue arrays ----
  int arr_fixed [4];
  int arr_dyn [];
  int arr_queue [$];
  int arr_assoc [string];

  // ---- 5. Structs ----
  typedef struct packed {bit [7:0] hi; bit [7:0] lo;} packed_t;
  typedef struct {int a; real b;} unpacked_t;
  packed_t     st_packed;
  unpacked_t   st_unpacked;

  // ---- 6. Classes ----
  class Plain;
    int x;
  endclass
  class Box #(type T = int);
    T val;
    function string val_typename();
      return $typename(val);
    endfunction
  endclass
  Plain        cls_plain;
  Box#(byte)   cls_box_byte;

  initial begin
    cls_plain = new;
    cls_box_byte = new;
    arr_dyn = new[2];
    arr_queue.push_back(1);
    arr_assoc["k"] = 1;

    // ---- 1. Atoms ----
    chk("int",              $typename(a_int),        "int");
    chk("int unsigned",     $typename(a_int_u),       "int unsigned");
    chk("integer",          $typename(a_integer),     "integer");
    chk("integer unsigned", $typename(a_integer_u),   "integer unsigned");
    chk("bit",               $typename(a_bit),        "bit");
    chk("bit unsigned",      $typename(a_bit_u),       "bit");
    chk("bit signed",        $typename(a_bit_s),       "bit signed");
    chk("byte",              $typename(a_byte),        "byte");
    chk("byte unsigned",     $typename(a_byte_u),      "byte unsigned");
    chk("shortint",          $typename(a_shortint),    "shortint");
    chk("shortint unsigned", $typename(a_shortint_u),  "shortint unsigned");
    chk("longint",           $typename(a_longint),     "longint");
    chk("longint unsigned",  $typename(a_longint_u),   "longint unsigned");
    chk("time",               $typename(a_time),       "time");
    chk("real",               $typename(a_real),       "real");
    chk("string",             $typename(a_string),     "string");
    chk("chandle",            $typename(a_chandle),    "chandle");

    // ---- 2. Packed vectors ----
    chk("logic [7:0]",        $typename(v_logic8),    "logic [7:0]");
    chk("bit [3:0]",          $typename(v_bit4),      "bit [3:0]");
    chk("logic signed [15:8]", $typename(v_logic_off), "logic signed [15:8]");

    // ---- 3. Enums ----
    chk("typedef enum",       $typename(en_typedef),
	"enum{ENUM_A=32'sd0,ENUM_B=32'sd1}en_typedef");
    chk("anonymous enum",     $typename(en_anon),
	"enum{ENUM_X=32'sd0,ENUM_Y=32'sd1,ENUM_Z=32'sd2}en_anon");
    chk("enum bit [1:0]",     $typename(en_narrow),
	"enum{RED=2'd0,GREEN=2'd1,BLUE=2'd2}en_narrow");

    // ---- 4. Arrays ----
    chk("fixed unpacked array",  $typename(arr_fixed), "int$[0:3]");
    chk("dynamic array",         $typename(arr_dyn),   "int$[]");
    chk("queue",                 $typename(arr_queue), "int$[$]");
    chk("associative array",     $typename(arr_assoc), "int$[string]");

    // ---- 5. Structs ----
    chk("packed struct",   $typename(st_packed),
	"struct packed {bit [7:0] hi;bit [7:0] lo;}");
    chk("unpacked struct", $typename(st_unpacked),
	"struct {int a;real b;}");

    // ---- 6. Classes ----
    chk("plain class",         $typename(cls_plain),    "Plain");
    chk("parameterized class", $typename(cls_box_byte), "Box");
    chk("class property",      $typename(cls_box_byte.val), "byte");
    chk("parameterized method T resolution",
	cls_box_byte.val_typename(), "byte");

    // ---- 7. $typename applied to a TYPE, not an expression ----
    chk("type argument: int",         $typename(int),        "int");
    chk("type argument: logic[7:0]",  $typename(logic[7:0]), "logic [7:0]");

    // ---- 8. Adversarial: expressions, selects ----
    chk("arithmetic expression",  $typename(a_int + 1),        "int");
    chk("part-select",            $typename(v_logic8[3:0]),    "logic [3:0]");
    chk("array element select",   $typename(arr_fixed[0]),     "int");

    if (fails == 0) $display("PASSED");
    else            $display("FAILED (%0d)", fails);
    $finish(0);
  end

endmodule
