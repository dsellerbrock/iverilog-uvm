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
class fixed_array_uniformity;
  rand bit mode;
  rand bit payload[2];
  constraint c {
    if (mode) { payload[0] == 0; payload[1] == 0; }
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
  uniform_struct_member member_uniform = new;
  wide_domain_uniformity wide_uniform = new;
  wide_domain_uniformity_above_cap wide_uniform_above_cap = new;
  fixed_array_uniformity fixed_array = new;
  int count[4];
  int variable_size_count[5];
  int variable_size_empty_count[11];
  int correlated_array_count[12];
  int larger_array_size_count[2];
  int member_tuple_count[3];
  int wide_tuple_count[5];
  int wide_above_cap_mode_one;
  int fixed_array_tuple_count[5];
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
    $display("PASSED");
  end
endmodule
