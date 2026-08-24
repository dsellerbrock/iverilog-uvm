// IEEE 1800-2023 19.5 and 19.7.1: labeled coverpoints may be selected
// hierarchically, and their instance-specific option values may be read and
// written procedurally after construction. The option state belongs to each
// covergroup instance.
class opentitan_coverpoint_options_wrap;
  covergroup tl_errors_cg(string name)
      with function sample(bit hit_value, bit miss_value);
    option.name = name;
    option.per_instance = 1;

    cp_hit: coverpoint hit_value {
      bins one = {1};
    }
    cp_miss: coverpoint miss_value {
      bins one = {1};
    }
  endgroup

  function new(string name);
    tl_errors_cg = new(name);
  endfunction
endclass

class cumulative_threshold_wrap;
  covergroup cg with function sample(bit value);
    cp: coverpoint value {
      bins one = {1};
    }
  endgroup

  function new;
    cg = new;
  endfunction
endclass

class opposite_weight_wrap;
  covergroup cg with function sample(bit first, bit second);
    cp_first: coverpoint first {
      bins one = {1};
    }
    cp_second: coverpoint second {
      bins one = {1};
    }
  endgroup

  function new;
    cg = new;
  endfunction
endclass

class ctor_weight_wrap;
  covergroup cg(int auxiliary_weight)
      with function sample(bit primary, bit auxiliary);
    cp_primary: coverpoint primary {
      bins one = {1};
    }
    cp_auxiliary: coverpoint auxiliary {
      option.weight = auxiliary_weight;
      bins one = {1};
    }
  endgroup

  function new(int auxiliary_weight);
    cg = new(auxiliary_weight);
  endfunction
endclass

class retired_threshold_wrap;
  covergroup cg with function sample(bit value);
    cp: coverpoint value {
      bins one = {1};
    }
  endgroup

  function new;
    cg = new;
  endfunction
endclass

class zero_threshold_family_wrap;
  int values[$];

  covergroup cg with function sample(int value);
    cp_dynamic: coverpoint value {
      bins values[] = values;
    }
    cp_transition: coverpoint value {
      bins paths[] = (1, 2 => 0 [*1:3] => 3, 4);
    }
  endgroup

  function new;
    values.push_back(1);
    cg = new;
  endfunction
endclass

class zero_threshold_cross_wrap;
  covergroup cg with function sample(bit first, bit second);
    cp_first: coverpoint first {
      bins one = {1};
    }
    cp_second: coverpoint second {
      bins one = {1};
    }
    pair: cross cp_first, cp_second;
  endgroup

  function new;
    cg = new;
  endfunction
endclass

class colliding_formal_wrap;
  covergroup cg(int __covgrp_item_0_option_at_least,
                int __covgrp_item_0_option_weight);
    cp_at: coverpoint __covgrp_item_0_option_at_least {
      bins expected = {7};
    }
    cp_weight: coverpoint __covgrp_item_0_option_weight {
      bins expected = {9};
    }
  endgroup

  function new(int at_bound, int weight_bound);
    cg = new(at_bound, weight_bound);
  endfunction
endclass

module main;
  // Match the OpenTitan cip_base_scoreboard access shape: an associative
  // array of wrapper objects containing the covergroup instance.
  opentitan_coverpoint_options_wrap tl_errors_cgs_wrap[string];
  string weighted_key;
  string thresholded_key;
  cumulative_threshold_wrap cumulative_a;
  cumulative_threshold_wrap cumulative_b;
  opposite_weight_wrap weight_a;
  opposite_weight_wrap weight_b;
  ctor_weight_wrap ctor_weight_enabled;
  ctor_weight_wrap ctor_weight_disabled;
  retired_threshold_wrap retired_low;
  retired_threshold_wrap retired_high;
  zero_threshold_family_wrap zero_families;
  zero_threshold_cross_wrap zero_cross;
  colliding_formal_wrap colliding;

  initial begin
    weighted_key = "weighted";
    thresholded_key = "thresholded";
    tl_errors_cgs_wrap[weighted_key] =
      new($sformatf("tl_errors_cg_%s", "weighted"));
    tl_errors_cgs_wrap[thresholded_key] =
      new($sformatf("tl_errors_cg_%s", "thresholded"));

    tl_errors_cgs_wrap[weighted_key].tl_errors_cg.cp_miss.option.weight = 0;
    tl_errors_cgs_wrap[weighted_key].tl_errors_cg.cp_miss.option.at_least = 0;
    tl_errors_cgs_wrap[thresholded_key].tl_errors_cg.cp_hit.option.at_least = 2;

    if (tl_errors_cgs_wrap[weighted_key].tl_errors_cg.cp_miss.option.weight != 0 ||
        tl_errors_cgs_wrap[weighted_key].tl_errors_cg.cp_miss.option.at_least != 0 ||
        tl_errors_cgs_wrap[weighted_key].tl_errors_cg.cp_hit.option.weight != 1 ||
        tl_errors_cgs_wrap[thresholded_key].tl_errors_cg.cp_hit.option.at_least != 2 ||
        tl_errors_cgs_wrap[thresholded_key].tl_errors_cg.cp_miss.option.at_least != 1) begin
      $fatal(1, "procedural coverpoint option readback was not per-instance");
    end

    tl_errors_cgs_wrap[weighted_key].tl_errors_cg.sample(1, 0);
    tl_errors_cgs_wrap[thresholded_key].tl_errors_cg.sample(1, 0);

    if (tl_errors_cgs_wrap[weighted_key].tl_errors_cg.get_inst_coverage() != 100.0 ||
        tl_errors_cgs_wrap[thresholded_key].tl_errors_cg.get_inst_coverage() != 0.0) begin
      $fatal(1, "first per-instance option coverage calculation was incorrect");
    end

    // Re-enable the zero-hit coverpoint. Its independent at_least=0 state
    // makes it covered, while the other instance still needs a second hit.
    tl_errors_cgs_wrap[weighted_key].tl_errors_cg.cp_miss.option.weight = 1;
    tl_errors_cgs_wrap[thresholded_key].tl_errors_cg.sample(1, 0);

    if (tl_errors_cgs_wrap[weighted_key].tl_errors_cg.get_inst_coverage() != 100.0 ||
        tl_errors_cgs_wrap[thresholded_key].tl_errors_cg.get_inst_coverage() != 50.0) begin
      $fatal(1, "updated per-instance option coverage calculation was incorrect");
    end

    // IEEE 1800-2023 19.11.1: cumulative coverage uses the maximum
    // option.at_least across all accumulated instances. get_coverage() is
    // static even when called through an instance, so both callers agree.
    cumulative_a = new;
    cumulative_b = new;
    cumulative_a.cg.cp.option.at_least = 1;
    cumulative_b.cg.cp.option.at_least = 3;
    cumulative_a.cg.sample(1);
    if (cumulative_a.cg.get_inst_coverage() != 100.0 ||
        cumulative_b.cg.get_inst_coverage() != 0.0 ||
        cumulative_a.cg.get_coverage() != 0.0 ||
        cumulative_b.cg.get_coverage() != 0.0) begin
      $fatal(1, "cumulative coverage did not use the maximum instance at_least");
    end

    // get_coverage() is static even when selected through an instance. Keep
    // its current merged model receiver-independent when instance weights
    // diverge; full merge_instances/type_option semantics remain separate.
    weight_a = new;
    weight_b = new;
    weight_a.cg.cp_first.option.weight = 1;
    weight_a.cg.cp_second.option.weight = 0;
    weight_b.cg.cp_first.option.weight = 0;
    weight_b.cg.cp_second.option.weight = 1;
    weight_a.cg.sample(1, 0);
    weight_b.cg.sample(1, 0);
    if (weight_a.cg.get_inst_coverage() != 100.0 ||
        weight_b.cg.get_inst_coverage() != 0.0 ||
        weight_a.cg.get_coverage() != 50.0 ||
        weight_b.cg.get_coverage() != 50.0) begin
      $fatal(1, "cumulative coverage depended on the calling instance");
    end

    // Declaration-time option.weight may directly name a constructor
    // formal. Its hidden mutable slot is initialized only after the formal
    // value has been stored on the new covergroup object.
    ctor_weight_enabled = new(1);
    ctor_weight_disabled = new(0);
    if (ctor_weight_enabled.cg.cp_auxiliary.option.weight != 1 ||
        ctor_weight_disabled.cg.cp_auxiliary.option.weight != 0) begin
      $fatal(1, "constructor-dependent item weight was not initialized");
    end
    ctor_weight_enabled.cg.sample(1, 0);
    ctor_weight_disabled.cg.sample(1, 0);
    if (ctor_weight_enabled.cg.get_inst_coverage() != 50.0 ||
        ctor_weight_disabled.cg.get_inst_coverage() != 100.0) begin
      $fatal(1, "constructor-dependent item weight was not effective");
    end

    // Accumulated type coverage keeps an instance's effective threshold
    // after its last handle is dropped. The counter remains accumulated, so
    // forgetting the threshold would incorrectly change 0% to 100% here.
    retired_low = new;
    retired_high = new;
    retired_low.cg.cp.option.at_least = 1;
    retired_high.cg.cp.option.at_least = 3;
    retired_high.cg.sample(1);
    if (retired_low.cg.get_coverage() != 0.0 ||
        retired_high.cg.get_coverage() != 0.0) begin
      $fatal(1, "cumulative coverage ignored a live maximum at_least");
    end
    retired_high = null;
    if (retired_low.cg.get_coverage() != 0.0) begin
      $fatal(1, "cumulative at_least changed after instance destruction");
    end

    // A zero threshold covers even zero-hit logical bins. A class-property
    // set creates compact dynamic-bin metadata and the repeated arrayed
    // transition creates a compact transition family; exercise both sparse
    // counter paths with no samples.
    zero_families = new;
    zero_families.cg.cp_dynamic.option.at_least = 0;
    zero_families.cg.cp_transition.option.at_least = 0;
    if (zero_families.cg.cp_dynamic.option.at_least != 0 ||
        zero_families.cg.cp_transition.option.at_least != 0 ||
        zero_families.cg.get_inst_coverage() != 100.0) begin
      $fatal(1, "zero at_least did not cover dynamic/transition families");
    end

    // Crosses carry their own item option state. Exclude the contributing
    // coverpoints and prove at_least=0 covers the unsampled cross bins.
    zero_cross = new;
    zero_cross.cg.cp_first.option.weight = 0;
    zero_cross.cg.cp_second.option.weight = 0;
    zero_cross.cg.pair.option.at_least = 0;
    if (zero_cross.cg.pair.option.at_least != 0 ||
        zero_cross.cg.get_inst_coverage() != 100.0) begin
      $fatal(1, "procedural cross option state was not effective");
    end

    // Legal constructor-formal names may resemble synthesized names. The
    // internal option slots must not alias or overwrite those formals.
    colliding = new(7, 9);
    if (colliding.cg.cp_at.option.at_least != 1 ||
        colliding.cg.cp_at.option.weight != 1 ||
        colliding.cg.cp_weight.option.at_least != 1 ||
        colliding.cg.cp_weight.option.weight != 1) begin
      $fatal(1, "item option defaults did not use independent slots");
    end
    colliding.cg.cp_at.option.at_least = 0;
    colliding.cg.cp_at.option.weight = 0;
    colliding.cg.cp_at.option.at_least = 1;
    colliding.cg.cp_at.option.weight = 1;
    colliding.cg.sample();
    if (colliding.cg.cp_at.option.at_least != 1 ||
        colliding.cg.cp_at.option.weight != 1 ||
        colliding.cg.get_inst_coverage() != 100.0) begin
      $fatal(1, "internal option slots collided with constructor formals");
    end

    $display("PASSED");
  end
endmodule
