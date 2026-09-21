// IEEE 1800-2017 18.5.4/18.5.10; IEEE 1800-2023 18.5.3/18.5.9.
// Multiple distributions in one component are sampled at their ordered stage.
class bit_leaf;
  rand bit value;
endclass

class ordered_pair;
  rand bit a, b;
  rand bit_leaf child;
  function new(); child = new; endfunction
  constraint c {
    solve a before b;
    a == b;
    child.value == b;
    a dist {0 := 1, 1 := 3};
    b dist {0 := 3, 1 := 1};
  }
endclass

class same_subject_pair;
  rand bit value;
  rand bit_leaf child;
  function new(); child = new; endfunction
  constraint c {
    child.value == value;
    value dist {0 := 1, 1 := 3};
    value dist {0 := 3, 1 := 1};
  }
endclass

class identical_pair;
  rand bit value;
  rand bit_leaf child;
  function new(); child = new; endfunction
  constraint c {
    child.value == value;
    value       dist {0 := 1, 1 := 3};
    child.value dist {0 := 1, 1 := 3};
  }
endclass

typedef enum bit [1:0] {
  ClkFreqDiffNone,
  ClkFreqDiffSmall,
  ClkFreqDiffBig,
  ClkFreqDiffAny
} clk_freq_diff_e;

`define CLOCK_DIST(V) \
  V dist {[5:23] :/ 2, [24:25] :/ 2, [26:47] :/ 1, \
          [48:50] :/ 2, [51:95] :/ 1, 96 :/ 1, \
          [97:99] :/ 1, 100 :/ 1}

class opentitan_clock_pair;
  rand bit_leaf child;
  rand int unsigned clk_freq_mhz;
  rand int unsigned edn_clk_freq_mhz;
  rand clk_freq_diff_e relation;
  bit [1:0] required_relation;

  function new(); child = new; endfunction

  constraint c {
    relation == required_relation;
    solve relation before edn_clk_freq_mhz;
    if (relation == ClkFreqDiffNone) {
      edn_clk_freq_mhz == clk_freq_mhz;
    } else if (relation == ClkFreqDiffSmall) {
      edn_clk_freq_mhz != clk_freq_mhz;
      int'(edn_clk_freq_mhz-clk_freq_mhz) inside {[-2:2]};
    } else if (relation == ClkFreqDiffBig) {
      !(int'(edn_clk_freq_mhz-clk_freq_mhz) inside {[-70:70]});
    }
    `CLOCK_DIST(clk_freq_mhz);
    `CLOCK_DIST(edn_clk_freq_mhz);
  }
endclass

module main;
  ordered_pair ordered = new;
  same_subject_pair same_subject = new;
  identical_pair identical = new;
  opentitan_clock_pair clocks[4];
  int ones, identical_ones;
  bit [63:0] replay[16];
  string state, child_state;

  initial begin
    ordered.srandom(32'h4f524452);
    ordered.child.srandom(32'h4f524443);
    repeat (4096) begin
      if (!ordered.randomize() || ordered.a != ordered.b
          || ordered.child.value != ordered.b)
        $fatal(1, "ordered coupled distributions failed");
      ones += ordered.a;
    end
    if (ones < 2800 || ones > 3350)
      $fatal(1, "earlier ordered dist marginal lost: %0d", ones);

    same_subject.srandom(32'h53414d45);
    same_subject.child.srandom(32'h53414d43);
    repeat (64)
      if (!same_subject.randomize()
          || same_subject.child.value != same_subject.value)
        $fatal(1, "same-subject distributions failed");

    identical.srandom(32'h4944454e);
    identical.child.srandom(32'h49444543);
    repeat (2048) begin
      if (!identical.randomize()
          || identical.child.value != identical.value)
        $fatal(1, "identical coupled distributions failed");
      identical_ones += identical.value;
    end
    if (identical_ones < 1400 || identical_ones > 1700)
      $fatal(1, "identical coupled marginal lost: %0d", identical_ones);

    for (int mode = 0; mode < 4; ++mode) begin
      clocks[mode] = new;
      clocks[mode].required_relation = mode;
      clocks[mode].srandom(32'h434c4b00 + mode);
      clocks[mode].child.srandom(32'h43484300 + mode);
      repeat (32) begin
        if (!clocks[mode].randomize())
          $fatal(1, "OpenTitan clock pair mode %0d failed", mode);
        if (clocks[mode].clk_freq_mhz < 5
            || clocks[mode].clk_freq_mhz > 100
            || clocks[mode].edn_clk_freq_mhz < 5
            || clocks[mode].edn_clk_freq_mhz > 100)
          $fatal(1, "clock distribution membership lost");
        case (mode)
          0: if (clocks[mode].edn_clk_freq_mhz
                 != clocks[mode].clk_freq_mhz)
               $fatal(1, "equal-clock relation lost");
          1: if (clocks[mode].edn_clk_freq_mhz
                   == clocks[mode].clk_freq_mhz
                 || int'(clocks[mode].edn_clk_freq_mhz
                         -clocks[mode].clk_freq_mhz) < -2
                 || int'(clocks[mode].edn_clk_freq_mhz
                         -clocks[mode].clk_freq_mhz) > 2)
               $fatal(1, "small-clock relation lost");
          2: if (int'(clocks[mode].edn_clk_freq_mhz
                         -clocks[mode].clk_freq_mhz) >= -70
                 && int'(clocks[mode].edn_clk_freq_mhz
                         -clocks[mode].clk_freq_mhz) <= 70)
               $fatal(1, "big-clock relation lost");
        endcase
      end
    end

    state = clocks[3].get_randstate();
    child_state = clocks[3].child.get_randstate();
    for (int i = 0; i < 16; ++i) begin
      if (!clocks[3].randomize()) $fatal(1, "replay setup failed");
      replay[i] = {clocks[3].clk_freq_mhz,
                   clocks[3].edn_clk_freq_mhz};
    end
    clocks[3].set_randstate(state);
    clocks[3].child.set_randstate(child_state);
    for (int i = 0; i < 16; ++i)
      if (!clocks[3].randomize()
          || replay[i] != {clocks[3].clk_freq_mhz,
                           clocks[3].edn_clk_freq_mhz})
        $fatal(1, "multiple-dist RNG replay changed");
    $display("PASSED");
  end
endmodule
