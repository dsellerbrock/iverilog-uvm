// IEEE 1800-2017 18.5.9/18.5.10; IEEE 1800-2023 18.5.8/18.5.9.
// Object replay: IEEE 1800-2017/2023 18.14.1/18.14.3.
class leaf;
  rand bit value;
endclass
class root;
  rand bit value;
  rand leaf child;
  function new(); child = new; endfunction
  constraint c { value >= child.value; }
endclass
class table18_2_unordered;
  rand bit s;
  rand bit [31:0] d;
  constraint c { s -> d == 0; }
endclass
class table18_2_ordered;
  rand bit s;
  rand bit [31:0] d;
  constraint c { s -> d == 0; }
  constraint order { solve s before d; }
endclass
class dynamic_array_unordered;
  rand bit m;
  rand bit [7:0] q[];
  constraint c { q.size() == 2; foreach (q[i]) m -> q[i] == 5; }
endclass
class dynamic_array_ordered;
  rand bit m;
  rand bit [7:0] q[];
  constraint c { q.size() == 2; foreach (q[i]) m -> q[i] == 5; }
  constraint order { solve m before q; }
endclass
class variable_size_array_unordered;
  rand bit short_case;
  rand bit payload[];
  constraint c {
    if (short_case) { payload.size() == 1; payload[0] == 0; }
    else payload.size() == 2;
  }
endclass
class variable_size_array_with_empty;
  rand bit [1:0] mode;
  rand bit payload[];
  constraint c {
    if (mode == 0) payload.size() == 0;
    else if (mode == 1) payload.size() == 1;
    else payload.size() == 2;
  }
endclass
class correlated_variable_arrays;
  rand bit mode;
  rand bit a[];
  rand bit b[];
  constraint c {
    if (mode) { a.size() == 1; b.size() == 2; a[0] == 0; }
    else { a.size() == 2; b.size() == 1; }
  }
endclass
class variable_size_array_above_old_cap;
  rand bit mode;
  rand bit payload[];
  constraint c {
    if (mode) payload.size() == 64;
    else payload.size() == 65;
  }
endclass
class variable_size_array_at_128_129;
  rand bit mode;
  rand bit payload[];
  constraint c {
    if (mode) payload.size() == 128;
    else payload.size() == 129;
  }
endclass
typedef struct {
  rand bit value;
} uniform_member_t;
class uniform_struct_member;
  rand bit selector;
  rand uniform_member_t record;
  constraint c { if (selector) record.value == 0; }
endclass
class wide_domain_uniformity;
  rand bit mode;
  rand bit [64:0] value;
  constraint c {
    if (mode) value == 65'd0;
    else value inside {65'd1, 65'd2, 65'd3, 65'd4};
  }
endclass
class wide_domain_uniformity_above_cap;
  rand bit mode;
  rand bit [64:0] value;
  constraint c {
    if (mode) value inside {[65'd1:65'd64]};
    else value == 65'd0;
  }
endclass
class wide_domain_uniformity_129;
  rand bit mode;
  rand bit [64:0] value;
  constraint c {
    if (mode) value inside {[65'd1:65'd128]};
    else value == 65'd0;
  }
endclass
class wide_domain_dense_uniformity;
  rand bit mode;
  rand bit [64:0] value;
  constraint c {
    if (mode) value != 65'd0;
    else value == 65'd0;
  }
endclass
class wide_single_range_uniformity;
  rand bit [64:0] value;
  constraint c { value inside {[65'd1:65'd1024]}; }
endclass
class wide_fragmented_ranges_uniformity;
  rand bit [64:0] value;
  constraint c {
    value inside {[65'd1:65'd768], [65'd1025:65'd1280]};
  }
endclass
class fixed_array_uniformity;
  rand bit mode;
  rand bit payload[2];
  constraint c {
    if (mode) { payload[0] == 0; payload[1] == 0; }
  }
endclass
class fixed_array_uniformity_above_128;
  rand bit mode;
  rand bit payload[129];
  constraint c {
    if (mode) { payload[0] == 0; payload[1] == 0; }
  }
endclass
class fixed_array_2d_uniformity;
  rand bit mode;
  rand bit payload[2][2];
  constraint c {
    if (mode) {
      payload[0][0] == 0;
      payload[0][1] == 0;
      payload[1][0] == 0;
      payload[1][1] == 0;
    }
  }
endclass
class fixed_array_3d_uniformity;
  rand bit mode;
  rand bit payload[2][2][2];
  constraint c {
    if (mode) {
      payload[0][0][0] == 0;
      payload[0][0][1] == 0;
      payload[0][1][0] == 0;
      payload[0][1][1] == 0;
      payload[1][0][0] == 0;
      payload[1][0][1] == 0;
      payload[1][1][0] == 0;
      payload[1][1][1] == 0;
    } else {
      payload[0][0][0] == 0;
      payload[0][0][1] == 0;
      payload[0][1][0] == 0;
      payload[0][1][1] == 0;
      payload[1][0][0] == 0;
    }
  }
endclass
module main;
  root r = new;
  root unrelated = new;
  table18_2_unordered unordered = new;
  table18_2_ordered ordered = new;
  dynamic_array_unordered dyn_unordered = new;
  dynamic_array_ordered dyn_ordered = new;
  variable_size_array_unordered variable_size = new;
  variable_size_array_with_empty variable_size_empty = new;
  correlated_variable_arrays correlated_arrays = new;
  variable_size_array_above_old_cap larger_array = new;
  variable_size_array_at_128_129 array_at_cap = new;
  uniform_struct_member member_uniform = new;
  wide_domain_uniformity wide_uniform = new;
  wide_domain_uniformity_above_cap wide_uniform_above_cap = new;
  wide_domain_uniformity_129 wide_uniform_129 = new;
  wide_domain_dense_uniformity wide_uniform_dense = new;
  wide_single_range_uniformity wide_single_range = new;
  wide_fragmented_ranges_uniformity wide_fragmented_ranges = new;
  fixed_array_uniformity fixed_array = new;
  fixed_array_uniformity_above_128 fixed_array_above_128 = new;
  fixed_array_2d_uniformity fixed_array_2d = new;
  fixed_array_3d_uniformity fixed_array_3d = new;
  int count[4];
  int variable_size_count[5];
  int variable_size_empty_count[11];
  int correlated_array_count[12];
  int larger_array_size_count[2];
  int array_at_cap_size_count[2];
  int member_tuple_count[3];
  int wide_tuple_count[5];
  int wide_above_cap_mode_one;
  int wide_129_mode_one;
  int wide_dense_mode_one;
  int wide_single_range_count[4];
  int wide_fragmented_ranges_count[4];
  int fixed_array_tuple_count[5];
  int fixed_array_above_128_tuple_count[5];
  int fixed_array_2d_tuple_count[17];
  int fixed_array_3d_tuple_count[9];
  bit [1:0] replay[20];
  int unordered_s1, ordered_s1;
  int dyn_unordered_m1, dyn_ordered_m1;
  string root_state, child_state;
  int noise;
  initial begin
    r.srandom(73); r.child.srandom(73);
    unordered.srandom(73); ordered.srandom(73);
    repeat (6000) begin
      if (!r.randomize()) $fatal(1, "joint solve failed");
      count[{r.value, r.child.value}]++;
    end

    if (count[1] || count[0] < 1800 || count[0] > 2200
        || count[2] < 1800 || count[2] > 2200
        || count[3] < 1800 || count[3] > 2200)
      $fatal(1, "joint tuples are not uniform");
    root_state = r.get_randstate(); child_state = r.child.get_randstate();
    for (int i=0; i<20; ++i) begin
      if (!r.randomize()) $fatal(1, "replay setup failed");
      replay[i] = {r.value, r.child.value};
    end
    r.set_randstate(root_state); r.child.set_randstate(child_state);
    for (int i=0; i<20; ++i) begin
      noise = $urandom;
      if (!unrelated.randomize()) $fatal(1, "unrelated solve failed");
      if (!r.randomize() || {r.value, r.child.value} != replay[i])
        $fatal(1, "joint RNG replay depends on unrelated calls");
    end

    // IEEE 1800-2017 Table 18-2 and 1800-2023 Table 18-1: without solve-before,
    // only one of 2^32+1 legal tuples has s==1. Ordering s before d changes the
    // marginal to a uniform choice of s first.
    repeat (256) begin
      if (!unordered.randomize() || !ordered.randomize())
        $fatal(1, "Table 18-2 randomization failed");
      unordered_s1 += unordered.s;
      ordered_s1 += ordered.s;
    end
    if (unordered_s1 > 10)
      $fatal(1, "unordered legal tuples are biased: s==1 %0d/256", unordered_s1);
    if (ordered_s1 < 90 || ordered_s1 > 166)
      $fatal(1, "solve-before marginal is biased: s==1 %0d/256", ordered_s1);

    // A two-element array has 2^16 legal tuples when m==0, but only one
    // when m==1. The unordered result should follow complete legal tuples;
    // solve-before intentionally keeps the marginal near one half.
    dyn_unordered.srandom(79); dyn_ordered.srandom(79);
    repeat (128) begin
      if (!dyn_unordered.randomize() || !dyn_ordered.randomize())
        $fatal(1, "dynamic-array randomization failed");
      if (dyn_unordered.m && (dyn_unordered.q[0] != 5 || dyn_unordered.q[1] != 5))
        $fatal(1, "unordered dynamic-array constraint failed");
      if (dyn_ordered.m && (dyn_ordered.q[0] != 5 || dyn_ordered.q[1] != 5))
        $fatal(1, "ordered dynamic-array constraint failed");
      dyn_unordered_m1 += dyn_unordered.m;
      dyn_ordered_m1 += dyn_ordered.m;
    end
    if (dyn_unordered_m1 > 3)
      $fatal(1, "unordered dynamic-array tuples are biased: m==1 %0d/128",
             dyn_unordered_m1);
    if (dyn_ordered_m1 < 40 || dyn_ordered_m1 > 88)
      $fatal(1, "dynamic-array solve-before marginal is biased: m==1 %0d/128",
             dyn_ordered_m1);

    // There are five complete legal tuples: one (small=1, bits=[0]) and
    // four (small=0, bits=[0:1] in {0,1}^2). Each tuple must be uniform.
    variable_size.srandom(97);
    repeat (500) begin
      if (!variable_size.randomize())
        $fatal(1, "variable-size dynamic-array randomization failed");
      if (variable_size.short_case) begin
        if (variable_size.payload.size() != 1 || variable_size.payload[0] != 0)
          $fatal(1, "invalid small-array solution");
        variable_size_count[0]++;
      end else begin
        if (variable_size.payload.size() != 2)
          $fatal(1, "invalid large-array solution");
        variable_size_count[1 + variable_size.payload[0]
                              + 2 * variable_size.payload[1]]++;
      end
    end
    for (int i = 0; i < 5; ++i)
      if (variable_size_count[i] < 70 || variable_size_count[i] > 130)
        $fatal(1, "variable-size legal tuple %0d is biased: %0d/500",
               i, variable_size_count[i]);

    // Empty, one-bit, and two-bit arrays form eleven complete legal tuples.
    variable_size_empty.srandom(98);
    repeat (500) begin
      if (!variable_size_empty.randomize())
        $fatal(1, "empty variable-size dynamic-array randomization failed");
      case (variable_size_empty.mode)
        0: begin
          if (variable_size_empty.payload.size() != 0)
            $fatal(1, "invalid empty-array solution");
          variable_size_empty_count[0]++;
        end
        1: begin
          if (variable_size_empty.payload.size() != 1)
            $fatal(1, "invalid one-bit-array solution");
          variable_size_empty_count[1 + variable_size_empty.payload[0]]++;
        end
        2, 3: begin
          if (variable_size_empty.payload.size() != 2)
            $fatal(1, "invalid two-bit-array solution");
          if (variable_size_empty.mode == 2)
            variable_size_empty_count[3 + variable_size_empty.payload[0]
                                      + 2 * variable_size_empty.payload[1]]++;
          else
            variable_size_empty_count[7 + variable_size_empty.payload[0]
                                      + 2 * variable_size_empty.payload[1]]++;
        end
      endcase
    end
    for (int i = 0; i < 11; ++i)
      if (variable_size_empty_count[i] < 20 || variable_size_empty_count[i] > 70)
        $fatal(1, "empty-array legal tuple %0d is biased: %0d/500",
               i, variable_size_empty_count[i]);

    // Two coupled array sizes produce twelve complete tuples in total.
    correlated_arrays.srandom(99);
    repeat (500) begin
      if (!correlated_arrays.randomize())
        $fatal(1, "correlated variable-size arrays failed");
      if (correlated_arrays.mode) begin
        if (correlated_arrays.a.size() != 1
            || correlated_arrays.b.size() != 2
            || correlated_arrays.a[0] != 0)
          $fatal(1, "invalid mode-one array tuple");
        correlated_array_count[correlated_arrays.b[0]
                               + 2 * correlated_arrays.b[1]]++;
      end else begin
        if (correlated_arrays.a.size() != 2
            || correlated_arrays.b.size() != 1)
          $fatal(1, "invalid mode-zero array tuple");
        correlated_array_count[4 + correlated_arrays.a[0]
                               + 2 * correlated_arrays.a[1]
                               + 4 * correlated_arrays.b[0]]++;
      end
    end
    for (int i = 0; i < 12; ++i)
      if (correlated_array_count[i] < 20 || correlated_array_count[i] > 70)
        $fatal(1, "correlated array tuple %0d is biased: %0d/500",
               i, correlated_array_count[i]);

    // The 65-element case has twice as many legal bit tuples as size 64.
    larger_array.srandom(100);
    repeat (300) begin
      if (!larger_array.randomize())
        $fatal(1, "larger variable-size array failed");
      if (larger_array.mode) begin
        if (larger_array.payload.size() != 64)
          $fatal(1, "invalid size-64 array tuple");
        larger_array_size_count[0]++;
      end else begin
        if (larger_array.payload.size() != 65)
          $fatal(1, "invalid size-65 array tuple");
        larger_array_size_count[1]++;
      end
    end
    if (larger_array_size_count[0] < 70 || larger_array_size_count[0] > 130
        || larger_array_size_count[1] < 170 || larger_array_size_count[1] > 230)
      $fatal(1, "large-array sizes are not weighted by complete tuples: %0d/%0d",
             larger_array_size_count[0], larger_array_size_count[1]);

    // The exact variable-size path also crosses its old 128-element cap.
    array_at_cap.srandom(403);
    repeat (300) begin
      if (!array_at_cap.randomize())
        $fatal(1, "128/129-element variable-size array failed");
      if (array_at_cap.mode) begin
        if (array_at_cap.payload.size() != 128)
          $fatal(1, "invalid size-128 array tuple");
        array_at_cap_size_count[0]++;
      end else begin
        if (array_at_cap.payload.size() != 129)
          $fatal(1, "invalid size-129 array tuple");
        array_at_cap_size_count[1]++;
      end
    end
    if (array_at_cap_size_count[0] < 70 || array_at_cap_size_count[0] > 130
        || array_at_cap_size_count[1] < 170 || array_at_cap_size_count[1] > 230)
      $fatal(1, "128/129 sizes are not weighted by complete tuples: %0d/%0d",
             array_at_cap_size_count[0], array_at_cap_size_count[1]);

    // One active struct member participates in the same three legal tuples.
    member_uniform.srandom(101);
    repeat (300) begin
      if (!member_uniform.randomize())
        $fatal(1, "struct-member uniformity solve failed");
      if (member_uniform.selector) begin
        if (member_uniform.record.value != 0)
          $fatal(1, "invalid selected struct-member tuple");
        member_tuple_count[0]++;
      end else
        member_tuple_count[1 + member_uniform.record.value]++;
    end
    for (int i = 0; i < 3; ++i)
      if (member_tuple_count[i] < 70 || member_tuple_count[i] > 130)
        $fatal(1, "struct-member legal tuple %0d is biased: %0d/300",
               i, member_tuple_count[i]);

    // A 65-bit variable has only five feasible values across the mode split.
    wide_uniform.srandom(211);
    repeat (1000) begin
      if (!wide_uniform.randomize())
        $fatal(1, "wide-domain uniformity solve failed");
      if (wide_uniform.mode) begin
        if (wide_uniform.value != 0)
          $fatal(1, "invalid wide mode-one tuple");
        wide_tuple_count[0]++;
      end else begin
        case (wide_uniform.value)
          65'd1: wide_tuple_count[1]++;
          65'd2: wide_tuple_count[2]++;
          65'd3: wide_tuple_count[3]++;
          65'd4: wide_tuple_count[4]++;
          default: $fatal(1, "invalid wide mode-zero tuple");
        endcase
      end
    end
    for (int i = 0; i < 5; ++i)
      if (wide_tuple_count[i] < 140 || wide_tuple_count[i] > 260)
        $fatal(1, "wide legal tuple %0d is biased: %0d/1000",
               i, wide_tuple_count[i]);

    // Sixty-four values on one side and one on the other make 65 legal tuples.
    wide_uniform_above_cap.srandom(233);
    repeat (100) begin
      if (!wide_uniform_above_cap.randomize())
        $fatal(1, "wide domain above enumeration cap failed");
      if (wide_uniform_above_cap.mode) begin
        if (wide_uniform_above_cap.value < 65'd1
            || wide_uniform_above_cap.value > 65'd64)
          $fatal(1, "invalid wide mode-one tuple");
        wide_above_cap_mode_one++;
      end else if (wide_uniform_above_cap.value != 0)
        $fatal(1, "invalid wide mode-zero tuple");
    end
    if (wide_above_cap_mode_one < 90)
      $fatal(1, "65 legal wide tuples are not sampled uniformly: mode one %0d/100",
             wide_above_cap_mode_one);

    // One branch has 128 legal values; the other has one.
    wide_uniform_129.srandom(624);
    repeat (200) begin
      if (!wide_uniform_129.randomize())
        $fatal(1, "129-tuple wide-domain solve failed");
      if (wide_uniform_129.mode) begin
        if (wide_uniform_129.value < 65'd1
            || wide_uniform_129.value > 65'd128)
          $fatal(1, "invalid 129-tuple mode-one value");
        wide_129_mode_one++;
      end else if (wide_uniform_129.value != 0)
        $fatal(1, "invalid 129-tuple mode-zero value");
    end
    if (wide_129_mode_one < 185)
      $fatal(1, "129 legal wide tuples are not sampled uniformly: mode one %0d/200",
             wide_129_mode_one);

    // The dense branch has more feasible values than the enumeration cap.
    wide_uniform_dense.srandom(625);
    repeat (200) begin
      if (!wide_uniform_dense.randomize())
        $fatal(1, "dense wide-domain solve failed");
      if (wide_uniform_dense.mode) begin
        if (wide_uniform_dense.value == 0)
          $fatal(1, "invalid dense mode-one value");
        wide_dense_mode_one++;
      end else if (wide_uniform_dense.value != 0)
        $fatal(1, "invalid dense mode-zero value");
    end
    if (wide_dense_mode_one < 190)
      $fatal(1, "large feasible domain is not sampled uniformly: mode one %0d/200",
             wide_dense_mode_one);

    // A single wide scalar's contiguous interval must be sampled uniformly.
    wide_single_range.srandom(626);
    repeat (200) begin
      if (!wide_single_range.randomize())
        $fatal(1, "wide single-range solve failed");
      if (wide_single_range.value < 65'd1
          || wide_single_range.value > 65'd1024)
        $fatal(1, "wide single-range result is outside its constraint");
      if (wide_single_range.value <= 65'd256)
        wide_single_range_count[0]++;
      else if (wide_single_range.value <= 65'd512)
        wide_single_range_count[1]++;
      else if (wide_single_range.value <= 65'd768)
        wide_single_range_count[2]++;
      else
        wide_single_range_count[3]++;
    end
    for (int i = 0; i < 4; ++i)
      if (wide_single_range_count[i] < 30 || wide_single_range_count[i] > 70)
        $fatal(1, "wide interval bucket %0d is biased: %0d/200",
               i, wide_single_range_count[i]);

    // Unequal disjoint intervals still give every legal value equal weight.
    wide_fragmented_ranges.srandom(627);
    repeat (200) begin
      if (!wide_fragmented_ranges.randomize())
        $fatal(1, "wide fragmented-range solve failed");
      if (wide_fragmented_ranges.value >= 65'd1
          && wide_fragmented_ranges.value <= 65'd256)
        wide_fragmented_ranges_count[0]++;
      else if (wide_fragmented_ranges.value >= 65'd257
               && wide_fragmented_ranges.value <= 65'd512)
        wide_fragmented_ranges_count[1]++;
      else if (wide_fragmented_ranges.value >= 65'd513
               && wide_fragmented_ranges.value <= 65'd768)
        wide_fragmented_ranges_count[2]++;
      else if (wide_fragmented_ranges.value >= 65'd1025
               && wide_fragmented_ranges.value <= 65'd1280)
        wide_fragmented_ranges_count[3]++;
      else
        $fatal(1, "wide fragmented-range result is outside its constraints");
    end
    for (int i = 0; i < 4; ++i)
      if (wide_fragmented_ranges_count[i] < 30
          || wide_fragmented_ranges_count[i] > 70)
        $fatal(1, "fragmented-range bucket %0d is biased: %0d/200",
               i, wide_fragmented_ranges_count[i]);

    // Fixed unpacked arrays also form five complete legal tuples.
    fixed_array.srandom(234);
    repeat (500) begin
      if (!fixed_array.randomize())
        $fatal(1, "fixed-array uniformity solve failed");
      if (fixed_array.mode) begin
        if (fixed_array.payload[0] || fixed_array.payload[1])
          $fatal(1, "invalid fixed-array mode-one tuple");
        fixed_array_tuple_count[0]++;
      end else
        fixed_array_tuple_count[1 + fixed_array.payload[0]
                                  + 2 * fixed_array.payload[1]]++;
    end
    for (int i = 0; i < 5; ++i)
      if (fixed_array_tuple_count[i] < 70 || fixed_array_tuple_count[i] > 130)
        $fatal(1, "fixed-array legal tuple %0d is biased: %0d/500",
               i, fixed_array_tuple_count[i]);

    // The other 127 leaves are independent free factors; the five projected
    // tuples still have equal multiplicity across the full 129-bit array.
    fixed_array_above_128.srandom(235);
    repeat (500) begin
      if (!fixed_array_above_128.randomize())
        $fatal(1, "large fixed-array uniformity solve failed");
      if (fixed_array_above_128.mode) begin
        if (fixed_array_above_128.payload[0]
            || fixed_array_above_128.payload[1])
          $fatal(1, "invalid large fixed-array mode-one tuple");
        fixed_array_above_128_tuple_count[0]++;
      end else
        fixed_array_above_128_tuple_count[1
          + fixed_array_above_128.payload[0]
          + 2 * fixed_array_above_128.payload[1]]++;
    end
    for (int i = 0; i < 5; ++i)
      if (fixed_array_above_128_tuple_count[i] < 70
          || fixed_array_above_128_tuple_count[i] > 130)
        $fatal(1, "129-element fixed-array tuple %0d is biased: %0d/500",
               i, fixed_array_above_128_tuple_count[i]);

    // A two-dimensional fixed array still has the same 17 complete tuples.
    fixed_array_2d.srandom(401);
    repeat (1000) begin
      int value;
      if (!fixed_array_2d.randomize())
        $fatal(1, "2D fixed-array uniformity solve failed");
      value = fixed_array_2d.payload[0][0]
        + 2 * fixed_array_2d.payload[0][1]
        + 4 * fixed_array_2d.payload[1][0]
        + 8 * fixed_array_2d.payload[1][1];
      if (fixed_array_2d.mode) begin
        if (value != 0)
          $fatal(1, "invalid 2D fixed-array mode-one tuple");
        fixed_array_2d_tuple_count[0]++;
      end else
        fixed_array_2d_tuple_count[value + 1]++;
    end
    for (int i = 0; i < 17; ++i)
      if (fixed_array_2d_tuple_count[i] < 30
          || fixed_array_2d_tuple_count[i] > 90)
        $fatal(1, "2D fixed-array tuple %0d is biased: %0d/1000",
               i, fixed_array_2d_tuple_count[i]);

    // Three unpacked dimensions also sample complete legal tuples uniformly.
    fixed_array_3d.srandom(402);
    repeat (300) begin
      int code;
      if (!fixed_array_3d.randomize())
        $fatal(1, "3D fixed-array uniformity solve failed");
      if (fixed_array_3d.mode) begin
        if (fixed_array_3d.payload[0][0][0]
            || fixed_array_3d.payload[0][0][1]
            || fixed_array_3d.payload[0][1][0]
            || fixed_array_3d.payload[0][1][1]
            || fixed_array_3d.payload[1][0][0]
            || fixed_array_3d.payload[1][0][1]
            || fixed_array_3d.payload[1][1][0]
            || fixed_array_3d.payload[1][1][1])
          $fatal(1, "invalid 3D fixed-array mode-one tuple");
        fixed_array_3d_tuple_count[0]++;
      end else begin
        if (fixed_array_3d.payload[0][0][0]
            || fixed_array_3d.payload[0][0][1]
            || fixed_array_3d.payload[0][1][0]
            || fixed_array_3d.payload[0][1][1]
            || fixed_array_3d.payload[1][0][0])
          $fatal(1, "invalid 3D fixed-array mode-zero tuple");
        code = {fixed_array_3d.payload[1][1][1],
                fixed_array_3d.payload[1][1][0],
                fixed_array_3d.payload[1][0][1]};
        fixed_array_3d_tuple_count[code + 1]++;
      end
    end
    for (int i = 0; i < 9; ++i)
      if (fixed_array_3d_tuple_count[i] < 12
          || fixed_array_3d_tuple_count[i] > 55)
        $fatal(1, "3D fixed-array tuple %0d is biased: %0d/300",
               i, fixed_array_3d_tuple_count[i]);
    $display("PASSED");
  end
endmodule
