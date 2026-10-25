// Check vpiTypespec on variables and nets (IEEE 1800-2023 37.25, 37.27):
// enums give their enum typespec, packed structs and unions give a struct or
// union typespec whose members carry their own typespecs (nested structs,
// enums, 2-state and 4-state vectors). Plain vectors and tagged unions (whose
// tag is not a member) have no typespec here.
package typespec_pkg;
  typedef enum logic [1:0] {IDLE, RUN, DONE = 3} state_t;
endpackage

module top;
  import typespec_pkg::*;
  typedef enum bit [2:0] {A = 1, B = 2, C = 4} small_t;
  typedef struct packed { logic [3:0] hi; state_t st; bit flag; } inner_t;
  typedef struct packed { inner_t in; logic [1:0][3:0] pair; int count; } outer_t;
  typedef union packed { logic [6:0] raw; inner_t in; } u_t;
  typedef union tagged packed { logic [3:0] a; bit [3:0] b; } tag_t;
  state_t st;
  small_t sm;
  inner_t in;
  outer_t out;
  u_t u;
  wire inner_t win = in;
  logic [7:0] plain;
  tag_t tg;
  initial #1 $show_typespec(st, sm, in, out, u, win, plain, tg);
endmodule
