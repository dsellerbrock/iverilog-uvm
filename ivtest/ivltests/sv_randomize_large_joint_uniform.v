// IEEE 1800-2017 §18.5.10 / IEEE 1800-2023 §18.5.9.
class heap_value;
  rand bit [7:0] v;
endclass

class heap_node extends heap_value;
  rand heap_value left, right;
  constraint heapcond { left.v <= v; right.v > v; }
endclass

module main;
  heap_node heap;
  integer left_sum = 0;
  integer value_sum = 0;
  integer right_sum = 0;

  initial begin
    heap = new;
    heap.left = new;
    heap.right = new;
    heap.srandom(32'h843);
    heap.left.srandom(32'h844);
    heap.right.srandom(32'h845);

    repeat (100) begin
      if (!heap.randomize())
        $fatal(1, "heap randomization failed");
      if (!(heap.left.v <= heap.v && heap.right.v > heap.v))
        $fatal(1, "heap randomization violated its constraint");
      left_sum += heap.left.v;
      value_sum += heap.v;
      right_sum += heap.right.v;
    end

    // The legal-tuple means are 63.5, 127, and 191.5 respectively. These
    // generous deterministic bounds reject the over-cap per-variable path.
    if (left_sum < 3500 || left_sum > 9500
        || value_sum < 9500 || value_sum > 15900
        || right_sum < 16000 || right_sum > 22500)
      $fatal(1, "large joint heap samples are biased: %0d/%0d/%0d",
             left_sum, value_sum, right_sum);
    $display("PASS: large joint heap samples are uniform");
  end
endmodule
