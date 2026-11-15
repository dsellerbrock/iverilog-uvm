// Issue #3291 (IEEE 1800-2023 37.25 detail 1, 37.26): a struct or union
// member declared through a typedef alias keeps the alias's vpiName, and
// vpiTypedefAlias returns the aliased typedef's typespec. $probe checks them.
module top;
  typedef enum bit [1:0] { R, G } primary_colors;
  typedef primary_colors colors;
  typedef colors hues;
  typedef struct packed { logic [3:0] a; logic b; } st_t;
  typedef st_t st2_t;
  typedef struct packed { colors hue; primary_colors p; hues h; st2_t s; logic x; } px_t;
  typedef union packed { colors c; logic [1:0] v; } un_t;
  px_t px;
  un_t un;
  initial #1 $probe;
endmodule
