// Issue #2667: unpacked structs, and fixed and open arrays of them, are DPI
// arguments with the C layout (IEEE 1800-2017/2023 H.7.8), passed by
// reference (H.8.7, H.8.8), with output/inout values copied back.
module test;
  typedef struct {
    byte b; real r; shortint h; logic l; longint q; int unsigned u;
    bit t; shortreal f; chandle p;
  } s_t;

  import "DPI-C" function real c_weigh(input s_t s);
  import "DPI-C" function void c_fill(output s_t s, input int seed);
  import "DPI-C" function void c_bump(inout s_t s);
  import "DPI-C" function real c_weigh_fixed(input s_t a[3]);
  import "DPI-C" function void c_fill_fixed(output s_t a[1:3]);
  import "DPI-C" function real c_weigh_open(input s_t a[]);
  import "DPI-C" function void c_bump_open(inout s_t a[]);

  bit failed = 0;

  task check_real(input string tag, input real got, input real want);
    if (got != want) begin
      $display("FAILED %s: got %f, want %f", tag, got, want);
      failed = 1;
    end
  endtask

  task check_s(input string tag, input s_t s, input int seed);
    if (s.b !== -seed || s.r != seed + 0.5 || s.h !== seed * 100
        || s.l !== 1'bz || s.q !== longint'(seed) << 40
        || s.u !== (32'hF000_0000 | seed) || s.t !== 1'b1
        || s.f != seed + 0.25) begin
      $display("FAILED %s: %p", tag, s);
      failed = 1;
    end
  endtask

  // Expected c_weigh() of the struct c_fill(seed) writes, with l == z (2).
  function automatic real filled_weight(int seed);
    return -seed + seed + 0.5 + seed * 100 + 2000 + real'(longint'(seed) << 40)
           + real'(32'hF000_0000 | seed) + 10000 + seed + 0.25 + 100000;
  endfunction

  s_t s, s2, sd, fa[3], fb[1:3], oa[];

  initial begin
    // A never-assigned struct has its members' default values (logic x).
    check_real("default input", c_weigh(sd), 3000);

    s = '{b:3, r:1.5, h:-7, l:1'b1, q:64'd5, u:9, t:1'b0, f:0.5, p:null};
    check_real("input", c_weigh(s), 3 + 1.5 - 7 + 1000 + 5 + 9 + 0.5);

    c_fill(s2, 4);
    check_s("output", s2, 4);
    check_real("output weight", c_weigh(s2), filled_weight(4));
    if (s2.p == null) begin
      $display("FAILED output chandle");
      failed = 1;
    end

    c_bump(s2);
    if (s2.b !== -3 || s2.r != 9.0 || s2.l !== 1'bx || s2.p != null) begin
      $display("FAILED inout: %p", s2);
      failed = 1;
    end

    fa[0] = s; fa[1] = s; fa[2] = s;
    fa[1].h = 1; fa[2].q = 100;
    check_real("fixed input", c_weigh_fixed(fa),
               6 * c_weigh(s) + 2 * 8 + 3 * 95);

    c_fill_fixed(fb);
    check_s("fixed output 1", fb[1], 1);
    check_s("fixed output 2", fb[2], 2);
    check_s("fixed output 3", fb[3], 3);

    oa = new[2];
    oa[0] = s; oa[1] = s;
    oa[1].u = 0;
    check_real("open input", c_weigh_open(oa), 2000000 + 3 * c_weigh(s) - 18);
    c_bump_open(oa);
    if (oa[0].b !== 4 || oa[1].b !== 4 || oa[0].r != 3.0 || oa[1].l !== 1'bx
        || oa[0].p == null || oa[1].u !== 0 || oa[0].u !== 9) begin
      $display("FAILED open inout: %p %p", oa[0], oa[1]);
      failed = 1;
    end

    if (!failed) $display("PASSED");
  end
endmodule
