// IEEE 1800-2017 §18.5.10 / IEEE 1800-2023 §18.5.9.
class sparse_size_array;
  rand bit payload[];
  constraint legal {
    payload.size() inside {1, 3};
    if (payload.size() == 3) payload[0] == 0;
  }
endclass

// With no explicit element references, the solver uses the dynamic-size
// sampler directly. The number of legal payload tuples still grows with size.
class sparse_size_unconstrained_array;
  rand bit payload[];
  constraint legal { payload.size() inside {1, 3}; }
endclass

class sparse_size_unsatisfiable;
  rand bit payload[];
  constraint impossible {
    payload.size() inside {1, 3};
    payload.size() == 2;
  }
endclass

module main;
  sparse_size_array item;
  sparse_size_unconstrained_array unconstrained;
  sparse_size_unsatisfiable impossible;
  integer tuple_count[6];
  integer unconstrained_size_one = 0;
  initial begin
    item = new;
    item.srandom(417);
    repeat (600) begin
      if (!item.randomize())
        $fatal(1, "sparse-size dynamic-array solve failed");
      if (item.payload.size() == 1)
        tuple_count[item.payload[0]]++;
      else if (item.payload.size() == 3) begin
        if (item.payload[0] != 0)
          $fatal(1, "invalid sparse size-three tuple");
        tuple_count[2 + 2 * item.payload[1] + item.payload[2]]++;
      end else
        $fatal(1, "sparse dynamic-array size escaped {1,3}");
    end
    if (tuple_count[0] + tuple_count[1] < 150
        || tuple_count[0] + tuple_count[1] > 250)
      $fatal(1, "sparse sizes are not weighted by legal tuples: size-one %0d/600",
             tuple_count[0] + tuple_count[1]);
    for (int i = 0; i < 6; ++i)
      if (tuple_count[i] < 60 || tuple_count[i] > 140)
        $fatal(1, "sparse-size legal tuple %0d is biased: %0d/600",
               i, tuple_count[i]);

    unconstrained = new;
    unconstrained.srandom(418);
    repeat (600) begin
      if (!unconstrained.randomize())
        $fatal(1, "unconstrained sparse-size dynamic-array solve failed");
      if (unconstrained.payload.size() == 1)
        unconstrained_size_one++;
      else if (unconstrained.payload.size() != 3)
        $fatal(1, "unconstrained sparse size escaped {1,3}");
    end
    // There are two legal size-one tuples and eight legal size-three tuples.
    if (unconstrained_size_one < 75 || unconstrained_size_one > 165)
      $fatal(1, "sparse sizes are not weighted by legal tuples: unconstrained size-one %0d/600",
             unconstrained_size_one);

    impossible = new;
    impossible.payload = new[1];
    impossible.payload[0] = 1;
    if (impossible.randomize())
      $fatal(1, "contradictory sparse-size constraint succeeded");
    if (impossible.payload.size() != 1 || impossible.payload[0] != 1)
      $fatal(1, "failed sparse-size randomization changed array state");
    $display("PASSED");
  end
endmodule
