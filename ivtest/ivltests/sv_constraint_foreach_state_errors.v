// IEEE 1800-2017 18.5.8.1, 18.5.13; IEEE 1800-2023 18.5.7.1, 18.5.12.
// Both editions 18.3, 18.6.1: unguarded invalid reads fail without writeback.
package error_map;
  class region;
    logic [31:0] lo;
    function new(int value); lo = value; endfunction
  endclass
  class device;
    region ranges[$];
  endclass
  device devices[$];
  class item;
    rand int addr;
    int posts;
    function void post_randomize(); posts++; endfunction
  endclass
endpackage
module main;
  import error_map::*;
  item req;
  device d;
  region r;
  int selected = 0;
  task check_unchanged;
    if (req.addr != 77 || req.posts != 0) $fatal(1, "failed solve changed state");
  endtask
  initial begin
    req = new; req.addr = 77;
    d = new; devices.push_back(d);
    repeat (4) begin r = new(55); d.ranges.push_back(r); end
    if (req.randomize() with {
      foreach (devices[selected].ranges[i])
        addr == devices[selected].ranges[2'sb11].lo;
    }) $fatal(1, "signed negative index accepted as index 3");
    check_unchanged();
    if (req.randomize() with {
      foreach (devices[selected].ranges[i])
        addr == devices[selected].ranges[i % 0].lo;
    }) $fatal(1, "zero divisor accepted");
    check_unchanged();
    d.ranges[0].lo = 'x;
    if (req.randomize() with {
      foreach (devices[selected].ranges[i]) addr == devices[selected].ranges[i].lo;
    }) $fatal(1, "X state silently changed to zero");
    check_unchanged();
    d.ranges[0] = null;
    if (req.randomize() with {
      foreach (devices[selected].ranges[i]) addr == devices[selected].ranges[i].lo;
    }) $fatal(1, "null element silently changed to zero");
    check_unchanged();
    if (!req.randomize() with {
      foreach (devices[selected].ranges[i])
        if (i > 0) addr == devices[selected].ranges[i].lo;
    } || req.addr != 55 || req.posts != 1) $fatal(1, "guarded null element failed");
    devices[0] = null;
    if (req.randomize() with {
      foreach (devices[selected].ranges[i]) addr == devices[selected].ranges[i].lo;
    }) $fatal(1, "null selected device accepted as empty queue");
    $display("PASSED");
  end
endmodule
