// Exact large-range dist-item regression candidate.
// Common checks exercise IEEE 1800-2017 18.5.4 / 2023 18.5.3.
// The := exclusion mass check is enabled only for 2023: its text expressly
// preserves the original range size after exclusions; 2017 is recorded as
// ambiguous in the accompanying assessment.
class signed_slash_item;
  rand bit signed [11:0] value;
  rand bit unrelated;
  constraint distribution_c {
    value dist {[-500:-300] :/ 1, [100:500] :/ 3};
  }
  constraint exclusion_c { value inside {-500, [100:500]}; }
  constraint unrelated_c { unrelated inside {0, 1}; }
endclass

class per_value_exclusion_item;
  rand bit [9:0] value;
  constraint distribution_c {
    value dist {[10:309] := 1, [310:409] := 1};
  }
  // Preserve just one member of the first source range. In 2023 its original
  // 300-member mass remains, so value 10 has probability 3/4.
  constraint exclusion_c { value inside {10, [310:409]}; }
endclass

class overlap_item;
  rand bit [9:0] value;
  constraint distribution_c {
    value dist {[0:300] :/ 1, [100:400] :/ 3,
                [500:499] :/ 0, 401 :/ 0};
  }
endclass

module test;
  signed_slash_item slash, left, right;
  per_value_exclusion_item per_value;
  overlap_item overlap;
  int slash_low, slash_high;
  int per_value_first, per_value_second;
  int overlap_low_only, overlap_middle, overlap_high_only;
  int failures;

  initial begin
    failures = 0;
    slash = new;
    slash.srandom(32'h600d_2017);
    repeat (128) begin
      if (!slash.randomize()) $fatal(1, "signed :/ randomize failed");
      if (slash.value == -500) slash_low++;
      else if (slash.value >= 100 && slash.value <= 500) slash_high++;
      else begin
        $display("DOMAIN_FAIL slash value=%0d unrelated=%0d", slash.value, slash.unrelated);
        failures++;
      end
    end
    // p(low)=1/4; the documented 128-draw band has a <1e-8 total false-rejection contribution.
    if (slash_low < 7 || slash_low > 65) begin
      $display("EXACT_REQUIRED_FAIL slash :/ item ratio 1:3");
      failures++;
    end

    per_value = new;
    per_value.srandom(32'h600d_2023);
    repeat (128) begin
      if (!per_value.randomize()) $fatal(1, ":= randomize failed");
      if (per_value.value == 10) per_value_first++;
      else if (per_value.value >= 310 && per_value.value <= 409) per_value_second++;
      else begin
        $display("DOMAIN_FAIL := value=%0d", per_value.value);
        failures++;
      end
    end
`ifdef DIST_2023
    // 2023: source masses are 300:100 despite the exclusion, hence p(first)=3/4.
    if (per_value_first < 63 || per_value_first > 121) begin
      $display("EXACT_REQUIRED_FAIL 2023 := retained source-range mass");
      failures++;
    end
`else
`endif

    overlap = new;
    overlap.srandom(32'h600d_0a11);
    repeat (256) begin
      if (!overlap.randomize()) $fatal(1, "overlap randomize failed");
      if (overlap.value <= 99) overlap_low_only++;
      else if (overlap.value <= 300) overlap_middle++;
      else if (overlap.value <= 400) overlap_high_only++;
      else begin
        $display("DOMAIN_FAIL overlap value=%0d", overlap.value);
        failures++;
      end
    end
    // Both exclusive regions must be reachable: P(no low-only in 256) < 3e-10.
    if (overlap_low_only == 0 || overlap_high_only == 0) begin
      $display("EXACT_REQUIRED_FAIL overlap additive item sampling");
      failures++;
    end

    // Reseeding must replay both the selected dist values and the unrelated
    // independent property; this does not treat the fallback warning as pass/fail.
    left = new; right = new;
    left.srandom(32'h1234_5678); right.srandom(32'h1234_5678);
    repeat (8) begin
      if (!left.randomize() || !right.randomize()) $fatal(1, "reseed randomize failed");
      if (left.value != right.value || left.unrelated != right.unrelated) begin
        $display("REPLAY_FAIL left=(%0d,%0d) right=(%0d,%0d)",
                 left.value, left.unrelated, right.value, right.unrelated);
        failures++;
      end
    end
    if (failures != 0) $fatal(1, "exact large-range dist checks failed: %0d", failures);
    $display("PASSED");
  end
endmodule
