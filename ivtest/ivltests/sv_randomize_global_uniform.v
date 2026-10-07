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
class soft_link_uniform;
  rand bit left;
  rand bit right;
  constraint preference { soft (left == 0 || right == 0); }
endclass
class soft_array_link_uniform;
  rand bit value[];
  constraint fixed_size { value.size() == 2; }
  constraint preference { soft (value[0] == 0 || value[1] == 0); }
endclass
class soft_fixed_foreach_uniform;
  rand bit mode;
  rand bit payload[2];
  constraint preference {
    foreach (payload[i]) soft (mode == 0 || payload[i] == 0);
  }
endclass
class soft_dynamic_size_foreach_ordering;
  rand bit mode;
  rand bit payload[];
  constraint size { if (mode) payload.size() == 1; else payload.size() == 2; }
  constraint preference {
    foreach (payload[i]) soft (mode == 0 || payload[i] == 0);
  }
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
class variable_size_array_at_256_257;
  rand bit mode;
  rand bit payload[];
  constraint c {
    if (mode) payload.size() == 256;
    else payload.size() == 257;
  }
endclass
class variable_size_array_at_512_513;
  rand bit mode;
  rand bit payload[];
  constraint c {
    if (mode) payload.size() == 512;
    else payload.size() == 513;
  }
endclass
typedef enum bit [1:0] {
  uniform_enum_one = 1,
  uniform_enum_two = 2,
  uniform_enum_three = 3
} variable_size_uniform_enum_t;
typedef enum bit { uniform_size_only_value = 1'b0 }
  variable_size_singleton_enum_t;
class variable_size_array_with_1025_sizes;
  rand variable_size_singleton_enum_t payload[];
  constraint c { payload.size() inside {[0:1024]}; }
endclass
class variable_size_enum_array_uniformity;
  rand bit short_case;
  rand variable_size_uniform_enum_t payload[];
  constraint c {
    if (short_case) payload.size() == 1;
    else payload.size() == 2;
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
class wide_single_range_257_uniformity;
  rand bit [256:0] value;
  constraint c { value inside {[257'd1:257'd1024]}; }
endclass
class wide_fragmented_ranges_uniformity;
  rand bit [64:0] value;
  constraint c {
    value inside {[65'd1:65'd768], [65'd1025:65'd1280]};
  }
endclass
class wide_nine_ranges_uniformity;
  rand bit [32:0] value;
  constraint c {
    value inside {
      [33'd1:33'd32], [33'd34:33'd65], [33'd67:33'd98],
      [33'd100:33'd131], [33'd133:33'd164], [33'd166:33'd197],
      [33'd199:33'd230], [33'd232:33'd263], [33'd265:33'd296]
    };
  }
endclass
class wide_thirty_three_ranges_uniformity;
  rand bit [32:0] value;
  constraint c {
    value inside {
      [33'd1:33'd8], [33'd10:33'd17], [33'd19:33'd26],
      [33'd28:33'd35], [33'd37:33'd44], [33'd46:33'd53],
      [33'd55:33'd62], [33'd64:33'd71], [33'd73:33'd80],
      [33'd82:33'd89], [33'd91:33'd98], [33'd100:33'd107],
      [33'd109:33'd116], [33'd118:33'd125], [33'd127:33'd134],
      [33'd136:33'd143], [33'd145:33'd152], [33'd154:33'd161],
      [33'd163:33'd170], [33'd172:33'd179], [33'd181:33'd188],
      [33'd190:33'd197], [33'd199:33'd206], [33'd208:33'd215],
      [33'd217:33'd224], [33'd226:33'd233], [33'd235:33'd242],
      [33'd244:33'd251], [33'd253:33'd260], [33'd262:33'd269],
      [33'd271:33'd278], [33'd280:33'd287], [33'd289:33'd296]
    };
  }
endclass
class wide_periodic_domain_uniformity;
  rand bit [32:0] value;
  constraint c { value[1:0] != 2'b11; }
endclass
class constrained_randc_wide_cycle;
  randc bit [10:0] value;
  constraint c { value inside {[0:127]}; }
  constraint impossible { value == 128; }
endclass
class coupled_constrained_randc;
  randc bit [10:0] value;
  rand leaf child;
  function new(); child=new; endfunction
  constraint c { value inside {[0:1024]}; child.value == value[0]; }
endclass
class coupled_fixed_array_randc;
  randc bit [10:0] value[2];
  rand leaf child;
  function new(); child=new; endfunction
  constraint c { value[0] inside {[0:1024]}; child.value == value[0][0]; }
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
  soft_link_uniform soft_uniform = new;
  soft_array_link_uniform soft_array_uniform = new;
  soft_fixed_foreach_uniform soft_fixed_foreach = new;
  soft_dynamic_size_foreach_ordering soft_dynamic_size_foreach = new;
  dynamic_array_unordered dyn_unordered = new;
  dynamic_array_ordered dyn_ordered = new;
  variable_size_array_unordered variable_size = new;
  variable_size_array_with_empty variable_size_empty = new;
  correlated_variable_arrays correlated_arrays = new;
  variable_size_array_above_old_cap larger_array = new;
  variable_size_array_at_128_129 array_at_cap = new;
  variable_size_array_at_256_257 array_at_next_cap = new;
  variable_size_array_at_512_513 array_above_uniform_cap = new;
  variable_size_array_with_1025_sizes array_many_sizes = new;
  variable_size_enum_array_uniformity enum_array = new;
  uniform_struct_member member_uniform = new;
  wide_domain_uniformity wide_uniform = new;
  wide_domain_uniformity_above_cap wide_uniform_above_cap = new;
  wide_domain_uniformity_129 wide_uniform_129 = new;
  wide_domain_dense_uniformity wide_uniform_dense = new;
  wide_single_range_uniformity wide_single_range = new;
  wide_single_range_257_uniformity wide_single_range_257 = new;
  wide_fragmented_ranges_uniformity wide_fragmented_ranges = new;
  wide_nine_ranges_uniformity wide_nine_ranges = new;
  wide_thirty_three_ranges_uniformity wide_thirty_three_ranges = new;
  wide_periodic_domain_uniformity wide_periodic_domain = new;
  constrained_randc_wide_cycle constrained_randc = new;
  coupled_constrained_randc coupled_randc = new;
  coupled_fixed_array_randc coupled_array_randc = new;
  fixed_array_uniformity fixed_array = new;
  fixed_array_uniformity_above_128 fixed_array_above_128 = new;
  fixed_array_2d_uniformity fixed_array_2d = new;
  fixed_array_3d_uniformity fixed_array_3d = new;
  int count[4];
  int soft_tuple_count[4];
  int soft_array_tuple_count[4];
  int soft_fixed_foreach_tuple_count[8];
  int soft_dynamic_size_foreach_count[5];
  int variable_size_count[5];
  int variable_size_empty_count[11];
  int correlated_array_count[12];
  int larger_array_size_count[2];
  int array_at_cap_size_count[2];
  int array_at_next_cap_size_count[2];
  int array_above_uniform_cap_size_count[2];
  int array_above_uniform_cap_first_bit_count;
  int array_many_size_histogram[4];
  int enum_array_size_count[2];
  int member_tuple_count[3];
  int wide_tuple_count[5];
  int wide_above_cap_mode_one;
  int wide_129_mode_one;
  int wide_dense_mode_one;
  int wide_single_range_count[4];
  int wide_single_range_257_count[4];
  int wide_fragmented_ranges_count[4];
  int wide_nine_ranges_count[9];
  int wide_nine_ranges_offset;
  int wide_thirty_three_ranges_count[33];
  int wide_thirty_three_ranges_offset;
  int wide_periodic_domain_count[3];
  bit constrained_randc_seen[2][128];
  bit coupled_randc_seen[1025];
  bit coupled_array_randc_seen[1025];
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
    coupled_randc.srandom(7721); coupled_randc.child.srandom(7723);
    repeat (32) begin
      if (!coupled_randc.randomize())
        $fatal(1, "coupled constrained randc solve failed");
      if (coupled_randc.value > 1024
          || coupled_randc.child.value != coupled_randc.value[0])
        $fatal(1, "coupled constrained randc escaped its feasible domain");
      if (coupled_randc_seen[coupled_randc.value])
        $fatal(1, "coupled constrained randc repeated within its cycle");
      coupled_randc_seen[coupled_randc.value] = 1;
    end

    coupled_array_randc.value[1].rand_mode(0);
    coupled_array_randc.srandom(7725);
    coupled_array_randc.child.srandom(7727);
    repeat (32) begin
      if (!coupled_array_randc.randomize())
        $fatal(1, "coupled fixed-array randc solve failed");
      if (coupled_array_randc.value[0] > 1024
          || coupled_array_randc.child.value
                != coupled_array_randc.value[0][0])
        $fatal(1, "coupled fixed-array randc violated its constraint");
      if (coupled_array_randc_seen[coupled_array_randc.value[0]])
        $fatal(1, "coupled fixed-array randc repeated within its cycle");
      coupled_array_randc_seen[coupled_array_randc.value[0]] = 1;
    end

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

    // The 512/513 case crosses the former complete-tuple cap; each larger
    // array size has twice as many legal bit-array tuples.
    array_at_next_cap.srandom(404);
    repeat (120) begin
      if (!array_at_next_cap.randomize())
        $fatal(1, "256/257-element variable-size array failed");
      if (array_at_next_cap.mode) begin
        if (array_at_next_cap.payload.size() != 256)
          $fatal(1, "invalid size-256 array tuple");
        array_at_next_cap_size_count[0]++;
      end else begin
        if (array_at_next_cap.payload.size() != 257)
          $fatal(1, "invalid size-257 array tuple");
        array_at_next_cap_size_count[1]++;
      end
    end
    if (array_at_next_cap_size_count[0] < 24
        || array_at_next_cap_size_count[0] > 56
        || array_at_next_cap_size_count[1] < 64
        || array_at_next_cap_size_count[1] > 96)
      $fatal(1, "256/257 sizes are not weighted by complete tuples: %0d/%0d out of 120",
             array_at_next_cap_size_count[0], array_at_next_cap_size_count[1]);

    array_above_uniform_cap.srandom(406);
    repeat (120) begin
      if (!array_above_uniform_cap.randomize())
        $fatal(1, "512/513-element variable-size array failed");
      if (array_above_uniform_cap.mode) begin
        if (array_above_uniform_cap.payload.size() != 512)
          $fatal(1, "invalid size-512 array tuple");
        array_above_uniform_cap_size_count[0]++;
      end else begin
        if (array_above_uniform_cap.payload.size() != 513)
          $fatal(1, "invalid size-513 array tuple");
        array_above_uniform_cap_size_count[1]++;
      end
      array_above_uniform_cap_first_bit_count +=
            array_above_uniform_cap.payload[0];
    end
    if (array_above_uniform_cap_size_count[0] < 20
        || array_above_uniform_cap_size_count[0] > 50
        || array_above_uniform_cap_size_count[1] < 70
        || array_above_uniform_cap_size_count[1] > 100)
      $fatal(1, "512/513 sizes are not weighted by complete tuples: %0d/%0d out of 120",
             array_above_uniform_cap_size_count[0],
             array_above_uniform_cap_size_count[1]);
    if (array_above_uniform_cap_first_bit_count < 35
        || array_above_uniform_cap_first_bit_count > 85)
      $fatal(1, "unconstrained array elements are not randomized: %0d/120 ones",
             array_above_uniform_cap_first_bit_count);

    // There are 1,025 legal sizes and one payload tuple at each size.
    // Size-domain sampling must not enumerate all 1,025 complete models.
    array_many_sizes.srandom(180008);
    repeat (400) begin
      if (!array_many_sizes.randomize())
        $fatal(1, "1,025-value dynamic-array size domain failed");
      if (array_many_sizes.payload.size() > 1024)
        $fatal(1, "dynamic-array size escaped its legal range");
      if (array_many_sizes.payload.size() <= 255)
        array_many_size_histogram[0]++;
      else if (array_many_sizes.payload.size() <= 511)
        array_many_size_histogram[1]++;
      else if (array_many_sizes.payload.size() <= 767)
        array_many_size_histogram[2]++;
      else
        array_many_size_histogram[3]++;
    end
    foreach (array_many_size_histogram[i])
      if (array_many_size_histogram[i] < 70
          || array_many_size_histogram[i] > 130)
        $fatal(1, "1,025 legal array sizes are not uniformly sampled: %0d,%0d,%0d,%0d",
               array_many_size_histogram[0], array_many_size_histogram[1],
               array_many_size_histogram[2], array_many_size_histogram[3]);

    // Three one-element tuples compete with nine two-element enum tuples.
    enum_array.srandom(405);
    repeat (120) begin
      if (!enum_array.randomize())
        $fatal(1, "variable-size enum array randomization failed");
      if (enum_array.short_case) begin
        if (enum_array.payload.size() != 1)
          $fatal(1, "invalid size-one enum array tuple");
        enum_array_size_count[0]++;
      end else begin
        if (enum_array.payload.size() != 2)
          $fatal(1, "invalid size-two enum array tuple");
        enum_array_size_count[1]++;
      end
      for (int i = 0; i < enum_array.payload.size(); ++i)
        if (enum_array.payload[i] != uniform_enum_one
            && enum_array.payload[i] != uniform_enum_two
            && enum_array.payload[i] != uniform_enum_three)
          $fatal(1, "invalid enum-array element");
    end
    if (enum_array_size_count[0] < 20 || enum_array_size_count[0] > 44
        || enum_array_size_count[1] < 84 || enum_array_size_count[1] > 108)
      $fatal(1, "enum-array sizes are not weighted by complete tuples: %0d/%0d out of 120",
             enum_array_size_count[0], enum_array_size_count[1]);

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

    // A satisfiable soft preference connects otherwise independent rand
    // variables and leaves three equally likely complete tuples.
    soft_uniform.srandom(5541);
    repeat (3000) begin
      if (!soft_uniform.randomize())
        $fatal(1, "soft-constrained uniformity solve failed");
      soft_tuple_count[{soft_uniform.left, soft_uniform.right}]++;
    end
    foreach (soft_tuple_count[i]) begin
      if (i == 0 || i == 1 || i == 2) begin
        if (soft_tuple_count[i] < 900 || soft_tuple_count[i] > 1100)
          $fatal(1, "soft-constrained legal tuple %0d is biased: %0d/3000",
                 i, soft_tuple_count[i]);
      end else if (soft_tuple_count[i] != 0)
        $fatal(1, "soft-constrained invalid tuple %0d occurred: %0d/3000",
               i, soft_tuple_count[i]);
    end

    soft_array_uniform.srandom(6533);
    repeat (1200) begin
      if (!soft_array_uniform.randomize())
        $fatal(1, "soft-constrained dynamic-array solve failed");
      if (soft_array_uniform.value.size() != 2)
        $fatal(1, "soft-constrained dynamic-array size changed");
      soft_array_tuple_count[{soft_array_uniform.value[0],
                              soft_array_uniform.value[1]}]++;
    end
    foreach (soft_array_tuple_count[i]) begin
      if (i == 0 || i == 1 || i == 2) begin
        if (soft_array_tuple_count[i] < 300
            || soft_array_tuple_count[i] > 500)
          $fatal(1, "soft-constrained array tuple %0d is biased: %0d/1200",
                 i, soft_array_tuple_count[i]);
      end else if (soft_array_tuple_count[i] != 0)
        $fatal(1, "invalid soft-constrained array tuple %0d occurred: %0d/1200",
               i, soft_array_tuple_count[i]);
    end

    // Per-element soft constraints leave five equally likely tuples:
    // four with mode zero, plus mode one with payload == 2'b00.
    soft_fixed_foreach.srandom(20261006);
    repeat (3000) begin
      if (!soft_fixed_foreach.randomize())
        $fatal(1, "soft foreach fixed-array solve failed");
      soft_fixed_foreach_tuple_count[
        {soft_fixed_foreach.mode, soft_fixed_foreach.payload[0],
         soft_fixed_foreach.payload[1]}]++;
    end
    for (int i = 0; i < 5; ++i)
      if (soft_fixed_foreach_tuple_count[i] < 450
          || soft_fixed_foreach_tuple_count[i] > 750)
        $fatal(1, "soft foreach tuple %0d is biased: %0d/3000", i,
               soft_fixed_foreach_tuple_count[i]);
    for (int i = 5; i < 8; ++i)
      if (soft_fixed_foreach_tuple_count[i] != 0)
        $fatal(1, "soft foreach invalid tuple %0d occurred: %0d", i,
               soft_fixed_foreach_tuple_count[i]);

    // Dynamic-array size constraints are solved before foreach constraints.
    soft_dynamic_size_foreach.srandom(20261008);
    repeat (3000) begin
      if (!soft_dynamic_size_foreach.randomize())
        $fatal(1, "soft foreach dynamic-size solve failed");
      if (soft_dynamic_size_foreach.mode) begin
        if (soft_dynamic_size_foreach.payload.size() != 1
            || soft_dynamic_size_foreach.payload[0] != 0)
          $fatal(1, "invalid size-one soft foreach result");
        soft_dynamic_size_foreach_count[4]++;
      end else begin
        if (soft_dynamic_size_foreach.payload.size() != 2)
          $fatal(1, "invalid size-two soft foreach result");
        soft_dynamic_size_foreach_count[
          {1'b0, soft_dynamic_size_foreach.payload[0],
           soft_dynamic_size_foreach.payload[1]}]++;
      end
    end
    for (int i = 0; i < 4; ++i)
      if (soft_dynamic_size_foreach_count[i] < 280
          || soft_dynamic_size_foreach_count[i] > 470)
        $fatal(1, "size-first foreach tuple %0d is biased: %0d/3000", i,
               soft_dynamic_size_foreach_count[i]);
    if (soft_dynamic_size_foreach_count[4] < 1350
        || soft_dynamic_size_foreach_count[4] > 1650)
      $fatal(1, "size-first mode marginal is biased: %0d/3000",
             soft_dynamic_size_foreach_count[4]);

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

    // The interval sampler also handles widths beyond the former 256-bit cap.
    wide_single_range_257.srandom(628);
    repeat (80) begin
      if (!wide_single_range_257.randomize())
        $fatal(1, "257-bit wide single-range solve failed");
      if (wide_single_range_257.value < 257'd1
          || wide_single_range_257.value > 257'd1024)
        $fatal(1, "257-bit wide interval result is outside its constraint");
      if (wide_single_range_257.value <= 257'd256)
        wide_single_range_257_count[0]++;
      else if (wide_single_range_257.value <= 257'd512)
        wide_single_range_257_count[1]++;
      else if (wide_single_range_257.value <= 257'd768)
        wide_single_range_257_count[2]++;
      else
        wide_single_range_257_count[3]++;
    end
    for (int i = 0; i < 4; ++i)
      if (wide_single_range_257_count[i] < 8
          || wide_single_range_257_count[i] > 32)
        $fatal(1, "257-bit wide interval bucket %0d is biased: %0d/80",
               i, wide_single_range_257_count[i]);

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

    // More than eight disjoint runs must still be sampled by cardinality.
    wide_nine_ranges.srandom(629);
    repeat (270) begin
      if (!wide_nine_ranges.randomize())
        $fatal(1, "wide nine-range solve failed");
      wide_nine_ranges_offset = int'(wide_nine_ranges.value) - 1;
      if (wide_nine_ranges_offset < 0
          || wide_nine_ranges_offset / 33 >= 9
          || wide_nine_ranges_offset % 33 >= 32)
        $fatal(1, "wide nine-range result is outside its constraints");
      wide_nine_ranges_count[wide_nine_ranges_offset / 33]++;
    end
    for (int i = 0; i < 9; ++i)
      if (wide_nine_ranges_count[i] < 12
          || wide_nine_ranges_count[i] > 48)
        $fatal(1, "nine-range bucket %0d is biased: %0d/270",
               i, wide_nine_ranges_count[i]);

    // Many narrow runs fit the bounded SAT-search budget without a run cap.
    wide_thirty_three_ranges.srandom(631);
    repeat (300) begin
      if (!wide_thirty_three_ranges.randomize())
        $fatal(1, "wide thirty-three-range solve failed");
      wide_thirty_three_ranges_offset =
          int'(wide_thirty_three_ranges.value) - 1;
      if (wide_thirty_three_ranges_offset < 0
          || wide_thirty_three_ranges_offset / 9 >= 33
          || wide_thirty_three_ranges_offset % 9 >= 8)
        $fatal(1, "wide thirty-three-range result is outside its constraints");
      wide_thirty_three_ranges_count[wide_thirty_three_ranges_offset / 9]++;
    end
    for (int i = 0; i < 33; ++i)
      if (wide_thirty_three_ranges_count[i] < 1
          || wide_thirty_three_ranges_count[i] > 22)
        $fatal(1, "33-range bucket %0d is biased: %0d/300",
               i, wide_thirty_three_ranges_count[i]);

    // Dense periodic legal values expose bias from the diversity fallback.
    wide_periodic_domain.srandom(632);
    repeat (300) begin
      if (!wide_periodic_domain.randomize())
        $fatal(1, "wide periodic-domain solve failed");
      if (wide_periodic_domain.value[1:0] == 2'b11)
        $fatal(1, "wide periodic-domain result is outside its constraints");
      wide_periodic_domain_count[
          wide_periodic_domain.value[1:0]]++;
    end
    for (int i = 0; i < 3; ++i)
      if (wide_periodic_domain_count[i] < 70
          || wide_periodic_domain_count[i] > 130)
        $fatal(1, "periodic-domain bucket %0d is biased: %0d/300",
               i, wide_periodic_domain_count[i]);

    // A constrained 11-bit randc property has only 128 legal cycle values.
    constrained_randc.srandom(7712);
    constrained_randc.impossible.constraint_mode(0);
    for (int cycle = 0; cycle < 2; cycle++) begin
      repeat (128) begin
        if (!constrained_randc.randomize())
          $fatal(1, "constrained wide randc solve failed");
        if (constrained_randc.value > 127)
          $fatal(1, "constrained wide randc result is outside its domain");
        if (constrained_randc_seen[cycle][constrained_randc.value])
          $fatal(1, "constrained wide randc repeated before completing its cycle");
        constrained_randc_seen[cycle][constrained_randc.value] = 1;
      end
      for (int value = 0; value < 128; value++)
        if (!constrained_randc_seen[cycle][value])
          $fatal(1, "constrained wide randc cycle missed a legal value");
      if (cycle == 0) begin
        constrained_randc.impossible.constraint_mode(1);
        if (constrained_randc.randomize())
          $fatal(1, "unsatisfiable constrained randc solve succeeded");
        constrained_randc.impossible.constraint_mode(0);
      end
    end

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
