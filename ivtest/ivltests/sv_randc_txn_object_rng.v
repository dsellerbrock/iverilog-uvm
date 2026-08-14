// Every random choice made for an object must come from that object's stream:
// exact constrained selection, dist, container sizing/fill, unpacked-struct
// leaves, and static properties randomized through that receiver.
typedef struct {
  rand bit [63:0] left;
  rand bit [63:0] right;
} randc_txn_rng_struct_t;

class randc_txn_rng_item;
  rand bit [7:0] exact_value;
  rand bit [7:0] dist_value;
  rand bit [7:0] data[];

  constraint exact_c { exact_value inside {8'd3, 8'd7, 8'd19, 8'd201}; }
  constraint dist_c { dist_value dist {8'd1 := 1, 8'd9 := 2, 8'd200 := 1}; }
  constraint data_c {
    data.size() == 3;
    foreach (data[i]) data[i] inside {[8'd1:8'd250]};
  }
endclass

class randc_txn_rng_struct_only;
  rand randc_txn_rng_struct_t payload;
endclass

class randc_txn_rng_static_only;
  static rand bit [63:0] value;
endclass

module test;
  initial begin
    randc_txn_rng_item item;
    randc_txn_rng_item noise;
    randc_txn_rng_item peer_0;
    randc_txn_rng_item peer_1;
    string baseline_state;
    bit [7:0] baseline_exact;
    bit [7:0] baseline_dist;
    bit [7:0] baseline_data[];
    bit [7:0] captured_exact;
    bit [7:0] captured_dist;
    bit [7:0] captured_data[];

    item = new;
    noise = new;
    peer_0 = new;
    peer_1 = new;
    item.exact_value = 8'h81;
    item.dist_value = 8'h82;
    item.data = new[1];
    item.data[0] = 8'h83;
    item.srandom(32'h4242_1717);
    baseline_state = item.get_randstate();
    baseline_exact = item.exact_value;
    baseline_dist = item.dist_value;
    baseline_data = item.data;

    if (item.randomize() !== 1)
      $fatal(1, "first object-RNG randomize failed");
    captured_exact = item.exact_value;
    captured_dist = item.dist_value;
    captured_data = item.data;

    item.exact_value = baseline_exact;
    item.dist_value = baseline_dist;
    item.data = baseline_data;
    item.set_randstate(baseline_state);
    if (item.randomize() !== 1)
      $fatal(1, "replayed object-RNG randomize failed");
    if (item.exact_value !== captured_exact
        || item.dist_value !== captured_dist
        || item.data.size() != captured_data.size())
      $fatal(1, "set_randstate did not replay solver choices");
    for (int i = 0; i < item.data.size(); i++)
      if (item.data[i] !== captured_data[i])
        $fatal(1, "set_randstate did not replay dynamic-array values");

    // Perturbing another object must not perturb a replay from ITEM's state.
    baseline_state = item.get_randstate();
    baseline_exact = item.exact_value;
    baseline_dist = item.dist_value;
    baseline_data = item.data;
    if (item.randomize() !== 1)
      $fatal(1, "independence reference randomize failed");
    captured_exact = item.exact_value;
    captured_dist = item.dist_value;
    captured_data = item.data;
    item.exact_value = baseline_exact;
    item.dist_value = baseline_dist;
    item.data = baseline_data;
    item.set_randstate(baseline_state);
    noise.srandom(32'h9999_0001);
    repeat (9)
      if (noise.randomize() !== 1) $fatal(1, "noise randomize failed");
    if (item.randomize() !== 1)
      $fatal(1, "post-noise target randomize failed");
    if (item.exact_value !== captured_exact
        || item.dist_value !== captured_dist
        || item.data.size() != captured_data.size())
      $fatal(1, "another object perturbed target solver choices");
    for (int i = 0; i < item.data.size(); i++)
      if (item.data[i] !== captured_data[i])
        $fatal(1, "another object perturbed target array fill");

    // Two independently constructed objects with equal seeds and equal
    // starting values must produce equal results.
    peer_0.data = new[1];
    peer_1.data = new[1];
    peer_0.data[0] = 8'h5a;
    peer_1.data[0] = 8'h5a;
    peer_0.srandom(32'h7777_3333);
    peer_1.srandom(32'h7777_3333);
    if (peer_0.randomize() !== 1 || peer_1.randomize() !== 1)
      $fatal(1, "same-seeded peer randomize failed");
    if (peer_0.exact_value !== peer_1.exact_value
        || peer_0.dist_value !== peer_1.dist_value
        || peer_0.data.size() != peer_1.data.size())
      $fatal(1, "same-seeded objects produced different solver results");
    for (int i = 0; i < peer_0.data.size(); i++)
      if (peer_0.data[i] !== peer_1.data[i])
        $fatal(1, "same-seeded objects produced different array values");

    begin
      randc_txn_rng_struct_only struct_item;
      string before_struct;
      struct_item = new;
      before_struct = struct_item.get_randstate();
      if (struct_item.randomize() !== 1)
        $fatal(1, "unpacked-struct-only randomize failed");
      if (struct_item.get_randstate() == before_struct)
        $fatal(1, "unpacked struct used a synthetic RNG instead of owner RNG");
    end

    begin
      randc_txn_rng_static_only static_item;
      string before_static;
      static_item = new;
      before_static = static_item.get_randstate();
      if (static_item.randomize() !== 1)
        $fatal(1, "static-only randomize failed");
      if (static_item.get_randstate() == before_static)
        $fatal(1, "static property did not consume receiver object RNG");
    end

    $display("PASSED");
  end
endmodule
