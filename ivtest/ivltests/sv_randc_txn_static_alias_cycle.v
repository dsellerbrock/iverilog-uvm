// A static randc property has one cycle per canonical declaring cell.  Base
// and sibling-derived receivers share it; a hidden declaration and a distinct
// parameter specialization do not.  Same-seeded receiver objects make every
// alias/isolation assertion deterministic.
class randc_txn_static_base;
  static randc bit [1:0] shared;
  constraint shared_active_c { shared inside {2'd0, 2'd1, 2'd2, 2'd3}; }
endclass

class randc_txn_static_left extends randc_txn_static_base;
endclass

class randc_txn_static_right extends randc_txn_static_base;
endclass

class randc_txn_static_hidden extends randc_txn_static_base;
  static randc bit [1:0] shared;
endclass

class randc_txn_static_param #(int TAG = 0);
  static randc bit [1:0] shared;
endclass

module test;
  initial begin
    randc_txn_static_base base_0;
    randc_txn_static_base base_1;
    randc_txn_static_left left;
    randc_txn_static_right right;
    randc_txn_static_hidden hidden;
    randc_txn_static_base hidden_base_view;
    bit [3:0] seen;
    bit [1:0] base_pick;
    bit [1:0] hidden_pick;

    base_0 = new;
    base_1 = new;
    left = new;
    right = new;
    hidden = new;
    hidden_base_view = hidden;
    base_0.srandom(32'h0123_4567);
    left.srandom(32'h0123_4567);
    right.srandom(32'h0123_4567);
    base_1.srandom(32'h0123_4567);
    seen = '0;
    if (base_0.randomize() !== 1) $fatal(1, "base randomize failed");
    if (seen[base_0.shared]) $fatal(1, "static base cycle repeated");
    seen[base_0.shared] = 1'b1;
    if (left.randomize() !== 1) $fatal(1, "left randomize failed");
    if (seen[left.shared]) $fatal(1, "left receiver forked static history");
    seen[left.shared] = 1'b1;
    if (right.randomize() !== 1) $fatal(1, "right randomize failed");
    if (seen[right.shared]) $fatal(1, "right receiver forked static history");
    seen[right.shared] = 1'b1;
    if (base_1.randomize() !== 1) $fatal(1, "second base randomize failed");
    if (seen[base_1.shared]) $fatal(1, "second base receiver forked static history");
    seen[base_1.shared] = 1'b1;
    if (seen !== 4'b1111)
      $fatal(1, "base/sibling receivers did not share one static cycle");

    // The base cycle is exactly exhausted.  Its next same-seeded pick and a
    // hidden declaration's first same-seeded pick must match if the histories
    // are independent.
    base_0.srandom(32'h89ab_cdef);
    hidden.srandom(32'h89ab_cdef);
    if (base_0.randomize(shared) !== 1) $fatal(1, "base reset-cycle call failed");
    base_pick = base_0.shared;
    if (hidden.randomize(shared) !== 1) $fatal(1, "hidden declaration call failed");
    hidden_pick = hidden.shared;
    if (base_pick !== hidden_pick)
      $fatal(1, "hidden declaration shared base randc history");

    hidden.shared.rand_mode(0);
    if (hidden.shared.rand_mode() !== 0
        || hidden_base_view.shared.rand_mode() !== 1)
      $fatal(1, "hidden and base rand_mode cells were not isolated");
    hidden.shared.rand_mode(1);

    begin
      randc_txn_static_param bare;
      randc_txn_static_param#() empty;
      randc_txn_static_param#(0) positional;
      randc_txn_static_param#(.TAG(0)) named;
      randc_txn_static_param#(1) tag1;
      bit [3:0] default_seen;
      bit [1:0] default_restart;
      bit [1:0] tag1_first;

      bare = new;
      empty = new;
      positional = new;
      named = new;
      tag1 = new;
      default_seen = '0;
      bare.srandom(32'h0bad_f00d);
      empty.srandom(32'h0bad_f00d);
      positional.srandom(32'h0bad_f00d);
      named.srandom(32'h0bad_f00d);
      if (bare.randomize(shared) !== 1) $fatal(1, "bare specialization failed");
      default_seen[bare.shared] = 1'b1;
      if (empty.randomize(shared) !== 1 || default_seen[empty.shared])
        $fatal(1, "empty-default specialization did not share history");
      default_seen[empty.shared] = 1'b1;
      if (positional.randomize(shared) !== 1 || default_seen[positional.shared])
        $fatal(1, "positional-default specialization did not share history");
      default_seen[positional.shared] = 1'b1;
      if (named.randomize(shared) !== 1 || default_seen[named.shared])
        $fatal(1, "named-default specialization did not share history");
      default_seen[named.shared] = 1'b1;
      if (default_seen !== 4'b1111)
        $fatal(1, "default specialization aliases did not complete one cycle");

      bare.srandom(32'h55aa_aa55);
      tag1.srandom(32'h55aa_aa55);
      if (bare.randomize(shared) !== 1) $fatal(1, "default restart failed");
      default_restart = bare.shared;
      if (tag1.randomize(shared) !== 1) $fatal(1, "nondefault first call failed");
      tag1_first = tag1.shared;
      if (default_restart !== tag1_first)
        $fatal(1, "nondefault specialization shared default randc history");

      tag1.shared.rand_mode(0);
      if (tag1.shared.rand_mode() !== 0 || bare.shared.rand_mode() !== 1)
        $fatal(1, "static rand_mode crossed specialization boundary");
      tag1.shared.rand_mode(1);
    end

    $display("PASSED");
  end
endmodule
