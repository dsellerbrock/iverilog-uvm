// IEEE 1800-2017/2023 §18.13.1–§18.13.5
class random_item;
  rand int unsigned value;
endclass

module test;
  initial begin
    int unsigned a, b, value;
    int unsigned process_a, process_b;
    string object_state, process_state;
    random_item item;
    process thread;

    if ($bits($urandom()) != 32)
      $fatal(1, "$urandom is not 32 bits");
    a = $urandom;
    b = $urandom();

    a = $urandom(42);
    a = $urandom();
    b = $urandom(42);
    b = $urandom();
    if (a !== b)
      $fatal(1, "$urandom seed did not reproduce the sequence");

    repeat (50) begin
      value = $urandom_range(50, 10);
      if (value < 10 || value > 50)
        $fatal(1, "$urandom_range returned %0d outside 10..50", value);
      value = $urandom_range(10, 50);
      if (value < 10 || value > 50)
        $fatal(1, "$urandom_range did not reverse its bounds: %0d", value);
      value = $urandom_range(5);
      if (value > 5)
        $fatal(1, "$urandom_range(max) returned %0d outside 0..5", value);
    end

    item = new;
    item.srandom(17);
    object_state = item.get_randstate();
    if (!item.randomize())
      $fatal(1, "object randomize failed after srandom");
    a = item.value;
    item.set_randstate(object_state);
    if (!item.randomize())
      $fatal(1, "object randomize failed after set_randstate");
    b = item.value;
    if (a !== b)
      $fatal(1, "object set_randstate did not restore its sequence");

    thread = process::self();
    thread.srandom(23);
    process_state = thread.get_randstate();
    process_a = $urandom();
    thread.set_randstate(process_state);
    process_b = $urandom();
    if (process_a !== process_b)
      $fatal(1, "process set_randstate did not restore its sequence");

    $display("PASS urandom clause 18.13");
  end
endmodule
