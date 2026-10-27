class excluded_assign_range;
  rand int value;
  constraint c {
    value > 101;
    value dist {[100:102] := 1, 103 := 1};
  }
endclass

class excluded_divide_range;
  rand bit [7:0] value;
  constraint c {
    value > 100;
    value dist {[100:101] :/ 1, 102 := 1};
  }
endclass

class excluded_large_assign_ranges;
  rand bit [31:0] value;
  constraint c {
    value dist {[0:32'h7fff_ffff] := 3,
                [32'h8000_0000:32'hffff_ffff] := 1};
    value >= 32'h8000_0000 || value[1:0] == 0;
  }
endclass

class excluded_large_divide_ranges;
  rand bit [31:0] value;
  constraint c {
    value dist {[0:32'h7fff_ffff] :/ 1,
                [32'h8000_0000:32'hffff_ffff] :/ 1};
    value inside {[0:1023], [32'h8000_0000:32'h8000_0fff]};
  }
endclass

class full_assign_range;
  rand bit [1:0] value;
  constraint c { value dist {[0:2] := 1, 3 := 1}; }
endclass

class all_weighted_ranges_excluded;
  rand int value;
  constraint c {
    value == 103;
    value dist {[100:102] := 1, [104:106] :/ 1, 103 := 1};
  }
endclass

class excluded_wide_divide_ranges;
  rand bit [63:0] value;
  constraint c {
    value dist {[64'h0000_0000_0000_0000:64'h0000_0003_ffff_ffff] :/ 1,
                [64'h0000_0004_0000_0000:64'h0000_0007_ffff_ffff] :/ 1,
                [64'h0000_0008_0000_0000:64'h0000_000b_ffff_ffff] :/ 1};
    value inside {[64'h0000_0000_0000_0000:64'h0000_0000_03ff_ffff],
                  [64'h0000_0004_0000_0000:64'h0000_0004_000f_ffff],
                  [64'h0000_0008_0000_0000:64'h0000_0008_000f_ffff]};
  }
endclass

module sv_dist_excluded_range_weight;
  excluded_assign_range assign_item;
  excluded_divide_range divide_item;
  excluded_large_assign_ranges large_assign_item;
  excluded_large_divide_ranges large_divide_item;
  full_assign_range full_assign_item;
  all_weighted_ranges_excluded all_excluded_item;
  excluded_wide_divide_ranges wide_divide_item;
  int assign_range, assign_scalar;
  int divide_range, divide_scalar;
  int large_assign_low, large_divide_low;
  int full_assign_count;
  int wide_low, wide_middle, wide_high;

  initial begin
    assign_item = new;
    divide_item = new;
    large_assign_item = new;
    large_divide_item = new;
    full_assign_item = new;
    all_excluded_item = new;
    wide_divide_item = new;
    assign_item.srandom(32'h8370_2017);
    divide_item.srandom(32'h8371_2017);
    large_assign_item.srandom(32'h8372_2017);
    large_divide_item.srandom(32'h8373_2017);
    full_assign_item.srandom(32'h8374_2017);
    wide_divide_item.srandom(32'h8375_2017);
    repeat (1500) begin
      if (!assign_item.randomize()) $fatal(1, "assign-range randomize failed");
      if (assign_item.value == 102) assign_range++;
      else if (assign_item.value == 103) assign_scalar++;
      else $fatal(1, "unexpected := value %0d", assign_item.value);

      if (!divide_item.randomize()) $fatal(1, "divide-range randomize failed");
      if (divide_item.value == 101) divide_range++;
      else if (divide_item.value == 102) divide_scalar++;
      else $fatal(1, "unexpected :/ value %0d", divide_item.value);
    end
    repeat (200) begin
      if (!large_assign_item.randomize()) $fatal(1, "large := randomize failed");
      if (large_assign_item.value < 32'h8000_0000) large_assign_low++;
      if (!large_divide_item.randomize()) $fatal(1, "large :/ randomize failed");
      if (large_divide_item.value < 32'h8000_0000) large_divide_low++;
    end
    repeat (1500) begin
      if (!full_assign_item.randomize()) $fatal(1, "full := randomize failed");
      if (full_assign_item.value < 3) full_assign_count++;
    end
    if (!all_excluded_item.randomize())
      $fatal(1, "all-excluded weighted ranges randomize failed");
    if (all_excluded_item.value != 103)
      $fatal(1, "all-excluded weighted ranges violated constraint");
    repeat (12) begin
      if (!wide_divide_item.randomize())
        $fatal(1, "wide :/ randomize failed");
      if (wide_divide_item.value < 64'h0000_0004_0000_0000)
        wide_low++;
      else if (wide_divide_item.value < 64'h0000_0008_0000_0000)
        wide_middle++;
      else
        wide_high++;
    end
    if (full_assign_count < 1000 || full_assign_count > 1250)
      $fatal(1, "full := range weight failed: %0d: %0d",
             full_assign_count, 1500-full_assign_count);

`ifdef EXPECT_2023
    // 1800-2023 §18.5.3 keeps the full := range mass (3:1) and the :/ item
    // mass (1:1) after exclusions.
    if (assign_range < 1000 || assign_range > 1250)
      $fatal(1, "2023 := weighting failed: %0d:%0d", assign_range, assign_scalar);
    if (divide_range < 625 || divide_range > 875)
      $fatal(1, "2023 :/ weighting failed: %0d:%0d", divide_range, divide_scalar);
    // The large := spans are equal, so their retained masses are 3:1;
    // both large :/ items retain weight 1, so the ratio is 1:1.
    if (large_assign_low < 130 || large_assign_low > 170)
      $fatal(1, "2023 large := weighting failed: low=%0d high=%0d",
             large_assign_low, 200-large_assign_low);
    if (large_divide_low < 80 || large_divide_low > 120)
      $fatal(1, "2023 large :/ weighting failed: low=%0d high=%0d",
             large_divide_low, 200-large_divide_low);
    // Each 2^34-value :/ range has a different sparse feasible subrange;
    // 2023 keeps the full item masses equal despite those exclusions.
    if (wide_low > 8)
      $fatal(1, "2023 wide :/ item weights failed: %0d:%0d:%0d",
             wide_low, wide_middle, wide_high);
`else
    // 1800-2017 §18.5.4 assigns := weight per value and divides :/ weight
    // over the original two values: the surviving ratios are 1:1 and 1:2.
    if (assign_range < 625 || assign_range > 875)
      $fatal(1, "2017 := weighting failed: %0d:%0d", assign_range, assign_scalar);
    if (divide_range < 375 || divide_range > 625)
      $fatal(1, "2017 :/ weighting failed: %0d:%0d", divide_range, divide_scalar);
    // The large := feasible masses are 3*2^29:2^31 (3:4); the large :/
    // feasible counts are 1024:4096, with equal original spans (1:4).
    if (large_assign_low < 65 || large_assign_low > 105)
      $fatal(1, "2017 large := weighting failed: low=%0d high=%0d",
             large_assign_low, 200-large_assign_low);
    if (large_divide_low < 20 || large_divide_low > 60)
      $fatal(1, "2017 large :/ weighting failed: low=%0d high=%0d",
             large_divide_low, 200-large_divide_low);
    // 2017 §18.5.4 divides by the original span, giving 2^26:2^20:2^20
    // (64:1:1) surviving masses. The scaled exact weights exceed 64 bits.
    if (wide_low < 9)
      $fatal(1, "2017 wide :/ per-value weights failed: %0d:%0d:%0d",
             wide_low, wide_middle, wide_high);
`endif
    $display("PASSED");
  end
endmodule
