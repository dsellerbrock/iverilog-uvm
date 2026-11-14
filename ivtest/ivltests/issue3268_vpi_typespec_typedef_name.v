// Issue #3268 (IEEE 1800-2023 37.25 detail 1): a typespec's vpiName is its
// typedef name, and NULL for a type without one. $probe checks it.
module top;
  typedef struct packed { logic [3:0] a; logic b; } st_t;
  typedef enum logic [1:0] { A, B } e_t;
  typedef struct packed { e_t kind; logic [2:0] v; } outer_t;
  st_t s;
  e_t e;
  outer_t o;
  struct packed { logic x; } anon;
  initial #1 $probe;
endmodule
