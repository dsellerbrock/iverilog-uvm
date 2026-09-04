// IEEE 1800-2017 18.5.8.1, 18.5.13; IEEE 1800-2023 18.5.7.1, 18.5.12.
// Both editions 11.6.1, 11.8.1, 11.8.2: both ternary arms determine its type.
package guard_map;
  typedef struct { logic [31:0] lo; } range_t;
  typedef struct { range_t ranges[$]; } device_t;
  device_t devices[$] = '{'{'{'{11}, '{22}, '{33}, '{44}}}};
  class item;
    rand int addr;
    rand int data[];
    bit enabled;
    rand bit disabled;
  endclass
endpackage
module main;
  import guard_map::*;
  item req;
  int selected = 0;
  initial begin
    req = new;
    if (!req.randomize() with {
      foreach (devices[selected].ranges[i])
        if (i == 0) addr == devices[selected].ranges[
          ((i == 0) ? 1'b1 : 2'b00) + 1'b1].lo;
    } || req.addr != 33) $fatal(1, "ternary index lost common width");
    req.disabled.rand_mode(0);
    req.disabled = 0;
    if (!req.randomize() with {
      addr == 9;
      foreach (devices[selected].ranges[i]) {
        enabled -> addr == devices[selected].ranges[i-1].lo;
        disabled -> addr == devices[selected].ranges[i-1].lo;
      }
    } || req.addr != 9) $fatal(1, "state property did not guard invalid read");
    if (!req.randomize(addr) with {
      addr == 9;
      foreach (devices[selected].ranges[i])
        disabled -> addr == devices[selected].ranges[i-1].lo;
    } || req.addr != 9) $fatal(1, "explicit active set did not preserve state guard");
    if (!req.randomize() with {
      foreach (devices[selected].ranges[i]) {
        if (i < 0) addr == devices[selected].ranges[i % 0].lo;
        if (i == 0) addr == devices[selected].ranges[
          (i == 0) ? 0 : devices[selected].ranges[-1].lo].lo;
      }
    } || req.addr != 11) $fatal(1, "inactive error changed ternary state index");
    if (!req.randomize() with {
      foreach (devices[selected].ranges[i])
        if (i == 0) addr == devices[selected].ranges[
          (i == 0) ? 2'sb11 : 4'b0].lo;
    } || req.addr != 44) $fatal(1, "unsigned ternary arm did not control extension");
    if (!req.randomize() with {
      data.size() == 2;
      foreach (data[j]) data[j] == j;
      foreach (devices[selected].ranges[i])
        if (i == 0) addr == devices[selected].ranges[i].lo;
    } || req.addr != 11 || req.data.size() != 2 || req.data[0] != 0 || req.data[1] != 1)
      $fatal(1, "independent random and state foreach templates interfered");
    $display("PASSED");
  end
endmodule
