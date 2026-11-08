// Issue #2667: struct members without a supported H.7.8 C layout (packed
// vectors, strings, nested structs) and unpacked unions are compile errors,
// never a silently skipped DPI call.
module test;
  typedef struct {logic [7:0] v; int i;} packed_member_t;
  typedef struct {string s;} string_member_t;
  typedef struct {int a;} inner_t;
  typedef struct {inner_t in; int b;} nested_t;
  typedef union {int a; real r;} u_t;
  import "DPI-C" function int c_packed(input packed_member_t s);
  import "DPI-C" function int c_string(input string_member_t s[]);
  import "DPI-C" function int c_nested(input nested_t s[2]);
  import "DPI-C" function int c_union(input u_t u);
  packed_member_t p; string_member_t sa[]; nested_t na[2]; u_t u;
  initial $display("%0d", c_packed(p) + c_string(sa) + c_nested(na) + c_union(u));
endmodule
