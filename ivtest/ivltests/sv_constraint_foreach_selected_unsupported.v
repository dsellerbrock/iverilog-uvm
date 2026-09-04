// IEEE 1800-2017/2023 18.7.1: target declarations precede caller lookup.
// Unsupported target roots/selectors retain a warning; scope randomization
// must issue a hard diagnostic rather than dropping the constraint.
package unsupported_map;
  typedef struct { int lo; } region_t;
  typedef struct { region_t ranges[$]; } device_t;
  device_t devices[$];
  class target;
    localparam int selected = 1;
    rand int addr;
  endclass
endpackage
module main;
  import unsupported_map::*;
  target req;
  int selected = 0;
  int addr;
  initial begin
    req = new;
    if (!req.randomize() with {
      foreach (devices[selected].ranges[i]) addr == devices[selected].ranges[i].lo;
    }) $finish;
    if (!std::randomize(addr) with {
      foreach (devices[selected].ranges[i]) addr == devices[selected].ranges[i].lo;
    }) $finish;
  end
endmodule
