class shallow_copy_rng_item;
  rand bit [15:0] value;
endclass

module test;
  initial begin
    shallow_copy_rng_item original;
    shallow_copy_rng_item copied;

    original = new;
    if (original.randomize() !== 1)
      $fatal(1, "initial randomize failed");
    copied = new original;
    if (original.randomize() !== 1 || copied.randomize() !== 1)
      $fatal(1, "post-copy randomize failed");
    if (original.value !== copied.value)
      $fatal(1, "shallow copy did not copy object RNG state");

    $display("PASSED");
  end
endmodule
