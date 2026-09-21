// Runtime core independent of the separately tracked state-foreach emitter.
typedef bit        [7:0] u8_t;
typedef bit       [15:0] u16_t;
typedef bit signed [15:0] s16_t;

class cast_core;
  rand bit [7:0] a, b, raw, logical_raw;
  rand int unsigned ua, ub;
  constraint c {
    a == 250; b == 10; raw == 255; logical_raw == 8'h80;
    ua == 5; ub == 6;
    int'(ub-ua) inside {[-2:2]};
    int'(a+b) == 260;
    int'(raw << 1) == 510;
    int'(!(logical_raw << 1)) == 1;
    8'(a+b) == 4;
    int'(u8_t'(a+b)) == 4;
    raw > 200;
    signed'(raw) < 0;
    unsigned'(signed'(raw)) == 255;
    int'(raw) == 255;
    int'(signed'(raw)) == -1;
    int'(unsigned'(signed'(raw))) == 255;
    s16_t'(signed'(raw)) == -1;
    u16_t'(signed'(raw)) == 16'hffff;
    u16_t'(raw) == 255;
  }
endclass

class cast_core_bad;
  rand bit [7:0] a, b;
  int posts;
  function void post_randomize(); posts++; endfunction
  constraint c { a == 250; b == 10; int'(a+b) == 261; }
endclass

module main;
  cast_core item = new;
  cast_core_bad bad = new;
  string rng;
  initial begin
    if (!item.randomize()) $fatal(1, "integral cast core failed");
    bad.a = 9; bad.b = 8; bad.srandom(32'h43415354);
    rng = bad.get_randstate();
    if (bad.randomize() || bad.a != 9 || bad.b != 8 || bad.posts != 0
        || bad.get_randstate() != rng)
      $fatal(1, "cast contradiction was not transactional");
    $display("PASSED");
  end
endmodule
