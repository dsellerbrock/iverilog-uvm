// Check that the FST dumper names enum values (FST enum tables) and dumps
// packed struct/union members as variables in a struct/union scope next to
// the whole vector, with nested structs, enum members, and $dumpoff x.
package fst_pkg;
  typedef enum logic [1:0] {IDLE, RUN, DONE = 3} state_t;
endpackage

module top;
  import fst_pkg::*;
  typedef enum bit [2:0] {A = 1, B = 2, C = 4} small_t;
  typedef struct packed { logic [3:0] hi; state_t st; bit flag; } inner_t;
  typedef struct packed { inner_t in; logic [1:0][3:0] pair; } outer_t;
  typedef union packed { logic [6:0] raw; inner_t in; } u_t;
  state_t st;
  small_t sm;
  inner_t in;
  outer_t out;
  u_t u;
  initial begin
    $fst_text("fst_enum_struct.fst");
    $dumpfile("fst_enum_struct.fst");
    $dumpvars(0, top);
    st = IDLE; sm = A; in = '0; out = '0; u = '0;
    #1 st = RUN; sm = C; in.hi = 4'h9; in.st = DONE; in.flag = 1;
    out.in.st = RUN; out.pair[1] = 4'h5;
    #1 u.in.st = DONE; u.in.hi = 4'hf;
    #1 $dumpoff;
    #1 $dumpon;
    #1 $finish(0);
  end
endmodule
