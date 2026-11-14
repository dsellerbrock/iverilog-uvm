// Issue #3276 (IEEE 1800-2023 37.25 detail 1): a typespec declared through
// a typedef alias has the alias's vpiName, and vpiTypedefAlias returns the
// aliased typedef's typespec. $probe checks them.
module top;
  typedef enum bit [0:2] { red, yellow, blue } primary_colors;
  typedef primary_colors colors;
  typedef colors hues;
  typedef struct packed { logic [3:0] a; logic b; } st_t;
  typedef st_t st2_t;
  colors c;
  primary_colors p;
  hues h;
  st2_t s2;
  initial #1 $probe;
endmodule
