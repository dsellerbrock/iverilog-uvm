// Campaign 6 wave 2 (rand CONTAINER/TYPE correctness cluster) evidence-pass
// regression pin, part 1 of 2: TYPE-SHAPE coverage that was found to already
// WORK but was previously untested -- pinned here so a future change cannot
// silently regress it. All objects are explicitly srandom()-seeded so the
// exact sequences checked below are reproducible.
//
// Covers: rand enum (incl. gapped encoding), packed struct, unpacked
// struct, wide bit[63:0], fixed-array element-wise fill, rand dynamic-array
// `.size()` constraint, and randc cycle-completeness for a plain vector and
// for an enum (both well under the 16-bit historical cap).
module sv_rand_conformance_pin1;

  typedef enum bit [1:0] {RED=0, GREEN=1, BLUE=2} color_e; // 2'b11 unused

  class EnumC;
    rand color_e col;
  endclass

  typedef struct packed {
    bit [3:0] a;
    bit [3:0] b;
  } packed_s;

  typedef struct {
    int x;
    bit [7:0] y;
  } unpacked_s;

  class ShapeC;
    rand packed_s   ps;
    rand unpacked_s us;
    rand bit [63:0] wide;
    rand bit [7:0]  arr[4];
  endclass

  class DArrC;
    rand int da[];
    constraint c_da { da.size() == 4; }
  endclass

  class RandcC;
    randc bit [2:0] v;
  endclass

  // Full-coverage enum (every bit[1:0] code names a value) for the randc
  // cycle-completeness check below. A GAPPED randc enum (one narrower than
  // its packed width, like color_e above) is a separate, weaker case: the
  // compiler synthesizes an `inside {legal values}' constraint for every
  // rand/randc enum property (elaborate.cc Phase 49) so an out-of-range
  // code is never produced, but once that constraint is non-trivial (as it
  // is for a gapped enum) the Z3 solve that enforces it is not aware of
  // randc's cycle-uniqueness bookkeeping, so legality is guaranteed but
  // strict one-of-each-before-any-repeat cycling is not (same as any other
  // constrained randc property, gapped enum or not -- see
  // sv_rand_conformance_pin1's history / Campaign 6 wave 2 notes). Full
  // coverage keeps the synthesized constraint trivially true, which keeps
  // the solver on its accept-current-value fast path and so keeps the
  // randc pre-fill's cyclic value intact.
  typedef enum bit [1:0] {A2=0, B2=1, C2=2, D2=3} full_color_e;

  class RandcEnumC;
    randc full_color_e col;
  endclass

  int errors = 0;

  initial begin
    // -- rand enum, incl. a code point (2'b11) that names no value --
    begin
      EnumC ec = new();
      int counts[4] = '{0,0,0,0};
      int illegal = 0;
      ec.srandom(1001);
      for (int i = 0; i < 300; i++) begin
        if (!ec.randomize()) begin $display("FAIL: enum randomize()==0"); errors++; end
        if (ec.col > BLUE) illegal++;
        counts[ec.col]++;
      end
      if (illegal != 0) begin
        $display("FAIL: enum produced %0d out-of-range (gap) values", illegal);
        errors++;
      end
      if (counts[0] == 0 || counts[1] == 0 || counts[2] == 0) begin
        $display("FAIL: enum randomize() never visited all 3 named values: %p", counts);
        errors++;
      end
    end

    // -- packed struct / unpacked struct / wide bit / fixed array --
    begin
      ShapeC sc = new();
      int wide_hi_nonzero = 0;
      int arr_changed = 0;
      int us_x_changed = 0;
      int us_y_changed = 0;
      int ps_changed = 0;
      bit [63:0] prev_wide;
      bit [7:0]  prev_arr0;
      int        prev_us_x;
      bit [7:0]  prev_us_y;
      bit [7:0]  prev_ps;
      sc.srandom(1002);
      void'(sc.randomize());
      prev_wide = sc.wide; prev_arr0 = sc.arr[0];
      prev_us_x = sc.us.x; prev_us_y = sc.us.y; prev_ps = sc.ps;
      for (int i = 0; i < 20; i++) begin
        if (!sc.randomize()) begin $display("FAIL: struct/wide randomize()==0"); errors++; end
        if (sc.wide[63:32] != 0) wide_hi_nonzero++;
        if (sc.arr[0] != prev_arr0) arr_changed++;
        if (sc.us.x != prev_us_x) us_x_changed++;
        if (sc.us.y != prev_us_y) us_y_changed++;
        if (sc.ps   != prev_ps)   ps_changed++;
        prev_wide = sc.wide; prev_arr0 = sc.arr[0];
        prev_us_x = sc.us.x; prev_us_y = sc.us.y; prev_ps = sc.ps;
      end
      if (wide_hi_nonzero == 0) begin
        $display("FAIL: rand bit[63:0] upper half never nonzero over 20 draws");
        errors++;
      end
      if (arr_changed == 0) begin
        $display("FAIL: rand fixed-array element never changed over 20 draws");
        errors++;
      end
      if (us_x_changed == 0 || us_y_changed == 0) begin
        $display("FAIL: rand unpacked-struct member(s) never changed: x_changed=%0d y_changed=%0d",
                  us_x_changed, us_y_changed);
        errors++;
      end
      if (ps_changed == 0) begin
        $display("FAIL: rand packed-struct value never changed over 20 draws");
        errors++;
      end
    end

    // -- rand dynamic array `.size()` constraint --
    begin
      DArrC dc = new();
      dc.srandom(1003);
      for (int i = 0; i < 10; i++) begin
        if (!dc.randomize()) begin $display("FAIL: darray-size randomize()==0"); errors++; end
        if (dc.da.size() != 4) begin
          $display("FAIL: darray size constraint violated: size=%0d", dc.da.size());
          errors++;
        end
      end
    end

    // -- randc cycle completeness: plain 3-bit vector, 3 consecutive cycles --
    begin
      RandcC rc_c = new();
      int ok_cycles = 0;
      int seen8[8];
      rc_c.srandom(1004);
      for (int cyc = 0; cyc < 3; cyc++) begin
        foreach (seen8[i]) seen8[i] = 0;
        for (int i = 0; i < 8; i++) begin
          void'(rc_c.randomize());
          seen8[rc_c.v]++;
        end
        begin
          bit all_once = 1;
          foreach (seen8[i]) if (seen8[i] != 1) all_once = 0;
          if (all_once) ok_cycles++;
          else begin $display("FAIL: randc bit[2:0] cycle %0d not a permutation: %p", cyc, seen8); errors++; end
        end
      end
      if (ok_cycles != 3) begin
        $display("FAIL: randc bit[2:0] ok_cycles=%0d/3", ok_cycles);
        errors++;
      end
    end

    // -- randc cycle completeness: enum (4 named values, full coverage),
    //    3 consecutive cycles --
    begin
      RandcEnumC re = new();
      int ok_cycles = 0;
      int seen4[4];
      re.srandom(1005);
      for (int cyc = 0; cyc < 3; cyc++) begin
        foreach (seen4[i]) seen4[i] = 0;
        for (int i = 0; i < 4; i++) begin
          void'(re.randomize());
          seen4[re.col]++;
        end
        begin
          bit all_once = 1;
          foreach (seen4[i]) if (seen4[i] != 1) all_once = 0;
          if (all_once) ok_cycles++;
          else begin $display("FAIL: randc enum cycle %0d not a permutation: %p", cyc, seen4); errors++; end
        end
      end
      if (ok_cycles != 3) begin
        $display("FAIL: randc enum ok_cycles=%0d/3", ok_cycles);
        errors++;
      end
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d)", errors);
  end
endmodule
