// IEEE 1800-2017 18.3, 18.5.8.1, 18.5.13, 18.7.1;
// IEEE 1800-2023 18.3, 18.5.7.1, 18.5.12, 18.7.1.
package range_map;
  typedef struct { bit [63:0] lo; bit [63:0] hi; } range_t;
  typedef struct { string name; range_t ranges[$]; } device_t;
  device_t devices[$];
  int selected;
  class request;
    rand bit [63:0] addr;
    int fixed = -1;
    int choose_on_pre = -1;
    bit clear_on_pre;
    int post_calls;
    function void pre_randomize();
      if (choose_on_pre >= 0) selected = choose_on_pre;
      if (clear_on_pre) devices[selected].ranges.delete();
    endfunction
    function void post_randomize(); post_calls++; endfunction
  endclass
endpackage

// The with-identifier list excludes this target declaration from lookup.
class shadow_request extends range_map::request;
  localparam int selected = 1;
endclass

class region;
  int lo, hi;
  function new(int low, int high); lo = low; hi = high; endfunction
endclass
class device;
  region ranges[$];
endclass

module main;
  import range_map::*;
  request req;
  shadow_request other_req;
  device handles[$];
  int i = 91; // the foreach iterator must shadow this declaration

  function automatic int draw_request();
    return req.randomize() with {
      addr inside {[0:1000]};
      if (fixed >= 0) addr == fixed;
      foreach (devices[selected].ranges[i])
        if (i > -1)
          !(addr inside {[devices[selected].ranges[i].lo:
                          devices[selected].ranges[i].hi]});
    };
  endfunction

  task automatic draw(int low, int high);
    repeat (20) begin
      if (!draw_request()) $fatal(1, "randomize failed");
      if (req.addr < low || req.addr > high)
        $fatal(1, "selected=%0d addr=%0d outside [%0d:%0d]", selected, req.addr, low, high);
      if (i != 91) $fatal(1, "outer iterator changed");
    end
  endtask

  initial begin
    req = new;
    devices = '{'{"a", '{'{0,990}}}, '{"b", '{'{10,1000}}}};
    selected = 0;
    draw(991, 1000);
    selected = 1;
    draw(0, 9);
    devices[1].ranges.push_back('{0,4});
    draw(5, 9);
    selected = 0;
    req.choose_on_pre = 1;
    draw(5, 9); // selected queue must be evaluated after the hook
    req.choose_on_pre = -1;
    req.clear_on_pre = 1;
    req.fixed = 555;
    draw(555, 555); // an empty queue has no exclusions
    req.clear_on_pre = 0;
    req.fixed = -1;
    devices[1].ranges = '{'{0,1000}};
    req.addr = 77;
    begin
      int posts;
      posts = req.post_calls;
      if (draw_request()) $fatal(1, "unsatisfiable exclusion accepted");
      if (req.addr != 77 || req.post_calls != posts)
        $fatal(1, "failed solve changed state or called post_randomize");
    end

    devices[1].ranges = '{'{7,7}, '{8,8}};
    repeat (20) begin
      if (!req.randomize() with {
        foreach (devices[selected].ranges[j])
          if ((devices[selected].ranges[j-1].lo == 7) && (j > 0))
            addr == devices[selected].ranges[j-1].lo;
      }) $fatal(1, "guarded neighbor solve failed");
      if (req.addr != 7) $fatal(1, "guarded neighbor was ignored");
    end

    begin
      device d;
      region r;
      d = new;
      r = new(0, 990);
      d.ranges.push_back(r);
      handles.push_back(d);
    end
    selected = 0;
    repeat (20) begin
      if (!req.randomize() with {
        addr inside {[0:1000]};
        foreach (handles[selected].ranges[k])
          !(addr inside {[handles[selected].ranges[k].lo:
                          handles[selected].ranges[k].hi]});
      }) $fatal(1, "class-handle queue solve failed");
      if (req.addr < 991 || req.addr > 1000)
        $fatal(1, "class-handle queue constraint was ignored");
    end
    other_req = new;
    selected = 0;
    if (!other_req.randomize() with (addr) {
      addr inside {[0:1000]};
      foreach (devices[selected].ranges[i])
        !(addr inside {[devices[selected].ranges[i].lo:devices[selected].ranges[i].hi]});
    } || other_req.addr < 991 || other_req.addr > 1000)
      $fatal(1, "with identifier list failed to select caller state");
    $display("PASSED");
  end
endmodule
