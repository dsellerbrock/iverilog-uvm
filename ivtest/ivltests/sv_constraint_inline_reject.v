// IEEE 1800-2017/2023 18.7: never omit an untranslated inline item.
package p;
  typedef struct { int lo; } region_t;
  typedef struct { region_t ranges[$]; } device_t;
  device_t devices[$];
  class target;
    localparam int selected = 0;
    rand int addr;
    function int sample();
      return randomize() with {
        foreach (devices[selected].ranges[i]) addr == devices[selected].ranges[i].lo;
      };
    endfunction
    function int scope_sample();
      return std::randomize(addr) with {
        foreach (devices[selected].ranges[i]) addr == devices[selected].ranges[i].lo;
      };
    endfunction
  endclass
endpackage
module main;
  import p::*;
  target req = new;
  localparam int selected = 0;
  initial begin
    if (!req.randomize() with {
      foreach (devices[selected].ranges[i]) addr == devices[selected].ranges[i].lo;
    }) $fatal(1, "randomize failed");
    void'(req.randomize() with {
      foreach (devices[selected].ranges[i]) addr == devices[selected].ranges[i].lo;
    });
    if (!std::randomize(req) with {
      foreach (devices[selected].ranges[i]) req.addr == devices[selected].ranges[i].lo;
    }) $fatal(1, "scope randomize failed");
  end
endmodule
