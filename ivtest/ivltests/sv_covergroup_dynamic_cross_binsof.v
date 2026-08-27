// IEEE 1800-2017/2023 19.6.1: named cross bins select resolved logical-bin
// identities. A dynamic dimension may be unconstrained by the selection, or
// selected directly by binsof(cp.bin); overlapping named bins each retain one
// aggregate counter while automatic bins cover only the unclaimed products.
module top;
  function automatic bit near(real got, real want);
    return got > want - 0.01 && got < want + 0.01;
  endfunction

  // Exact shape shared by OpenTitan's cip_base_env_cov::intr_test_cg.
  covergroup intr_test_cg(int n)
      with function sample(int intr, bit intr_test, bit intr_en,
                           bit intr_state);
    option.per_instance = 1;
    cp_intr: coverpoint intr {
      bins all_values[] = {[0:n-1]};
    }
    cp_intr_test: coverpoint intr_test;
    cp_intr_en: coverpoint intr_en;
    cp_intr_state: coverpoint intr_state;
    intr_cross: cross cp_intr, cp_intr_test, cp_intr_en, cp_intr_state {
      illegal_bins test_1_state_0 =
          binsof(cp_intr_test) intersect {1} &&
          binsof(cp_intr_state) intersect {0};
    }
  endgroup

  // Exact named-selection structure used by OpenTitan's I2C SCL-stretch
  // coverage. The two named cross bins overlap on (not_empty, empty).
  covergroup fifo_cg(int n)
      with function sample(int acq_size, int tx_size, bit enable);
    option.per_instance = 1;
    cp_acq: coverpoint acq_size {
      bins empty = {0};
      bins not_empty = {[1:n-1]};
    }
    cp_tx: coverpoint tx_size {
      bins empty = {0};
      bins not_empty = {[1:n-1]};
    }
    fifo_cross: cross cp_acq, cp_tx iff (enable) {
      bins read_byte_stretch =
          binsof(cp_acq.not_empty) && binsof(cp_tx.empty);
      bins stretch_request = binsof(cp_acq.not_empty);
    }
  endgroup

  // Unsized integral array bins are keyed by their resolved value, not by a
  // dense zero-based ordinal. Three overlapping named bins make that identity
  // observable while the 2017 default retains unclaimed automatic bins; one
  // escaped bin identifier also verifies quote-safe VVP serialization.
  covergroup offset_cg(int lo, int hi)
      with function sample(int idx, bit flag);
    option.per_instance = 1;
    cp_idx: coverpoint idx {
      bins each[] = {[lo:hi]};
    }
    cp_flag: coverpoint flag;
    offset_cross: cross cp_idx, cp_flag {
      bins first = binsof(cp_idx) intersect {100} &&
                   binsof(cp_flag) intersect {0};
      bins first_again = binsof(cp_idx) intersect {100} &&
                         binsof(cp_flag) intersect {0};
      bins \quoted"name = binsof(cp_idx) intersect {100} &&
                           binsof(cp_flag) intersect {0};
    }
  endgroup

  // A fixed wildcard source still participates in a constructor-dependent
  // cross. The intersect tests the wildcard's represented value set, not the
  // internal (value, care-mask) encoding.
  covergroup wildcard_cg(int lo, int hi)
      with function sample(int idx, bit [7:0] code);
    option.per_instance = 1;
    cp_idx: coverpoint idx {
      bins each[] = {[lo:hi]};
    }
    cp_code: coverpoint code {
      wildcard bins a = {8'b1010????};
    }
    wildcard_cross: cross cp_idx, cp_code {
      bins selected = binsof(cp_idx) intersect {100} &&
                      binsof(cp_code.a) intersect {8'ha5};
      bins selected_again = binsof(cp_idx) intersect {100} &&
                            binsof(cp_code.a) intersect {8'ha5};
    }
  endgroup

  // Cross counter identities are structural. Two unlabeled crosses with the
  // same source-language bin name must never alias a synthesized property.
  covergroup collision_cg(int n)
      with function sample(int idx, bit flag);
    option.per_instance = 1;
    cp_idx: coverpoint idx {
      bins each[] = {[0:n-1]};
    }
    cp_flag: coverpoint flag;
    cross cp_idx, cp_flag {
      bins same = binsof(cp_idx) intersect {0} &&
                  binsof(cp_flag) intersect {0};
    }
    cross cp_idx, cp_flag {
      bins same = binsof(cp_idx) intersect {0} &&
                  binsof(cp_flag) intersect {0};
    }
  endgroup

  // Source-bin counters also need structural property identities. These two
  // legal scoped names used to flatten to the same `__bin_a_b_c` spelling;
  // the second bin then pointed at the next coverpoint's option slot. The
  // constructor-dependent third dimension makes the corrupted identity flow
  // through the per-instance cross plan as well as the source coverpoint.
  covergroup source_collision_cg(int n)
      with function sample(int left, int right, int idx);
    option.per_instance = 1;
    a_b: coverpoint left {
      bins c = {0};
    }
    a: coverpoint right {
      bins b_c = {0};
    }
    dynamic_cp: coverpoint idx {
      bins each[] = {[0:n-1]};
    }
    source_collision_cross: cross a_b, a, dynamic_cp;
  endgroup

  intr_test_cg intr_cov = new(2);
  fifo_cg fifo_cov = new(4);
  offset_cg offset_cov = new(100, 101);
  wildcard_cg wildcard_cov = new(100, 101);
  collision_cg collision_cov = new(2);
  source_collision_cg source_collision_cov = new(1);

  initial begin
    intr_cov.sample(0, 0, 0, 0);
    if (!near(intr_cov.get_inst_coverage(), 41.6667))
      $fatal(1, "unconstrained dynamic cross dimension routed incorrectly");

    fifo_cov.sample(1, 1, 1);
    if (!near(fifo_cov.get_inst_coverage(), 41.6667))
      $fatal(1, "named dynamic binsof selection has the wrong topology");

    fifo_cov.sample(2, 0, 1);
    if (!near(fifo_cov.get_inst_coverage(), 66.6667))
      $fatal(1, "overlapping named cross bins did not count independently");

    fifo_cov.sample(0, 0, 0);
    if (!near(fifo_cov.get_inst_coverage(), 83.3333))
      $fatal(1, "cross iff did not leave contributing coverpoints sampled");

    offset_cov.sample(100, 0);
    if (!near(offset_cov.get_inst_coverage(), 50.0))
      $fatal(1, "nonzero unsized logical-bin identity was treated as an ordinal");

    wildcard_cov.sample(100, 8'ha5);
    if (!near(wildcard_cov.get_inst_coverage(), 72.2222))
      $fatal(1, "wildcard binsof intersect used the pattern encoding as a range");

    collision_cov.sample(0, 0);
    if (!near(collision_cov.get_inst_coverage(), 37.5))
      $fatal(1, "unlabeled cross counters collided");

    source_collision_cov.sample(0, 0, 0);
    if (!near(source_collision_cov.get_inst_coverage(), 100.0))
      $fatal(1, "source-bin hidden counters collided");

    $display("PASSED");
    $finish;
  end
endmodule
