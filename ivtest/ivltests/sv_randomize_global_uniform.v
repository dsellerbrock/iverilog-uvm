// IEEE 1800-2017 18.5.9/18.5.10; IEEE 1800-2023 18.5.8/18.5.9.
// Object replay: IEEE 1800-2017/2023 18.14.1/18.14.3.
class leaf;
  rand bit value;
endclass
class root;
  rand bit value;
  rand leaf child;
  function new(); child = new; endfunction
  constraint c { value >= child.value; }
endclass
module main;
  root r = new;
  root unrelated = new;
  int count[4];
  bit [1:0] replay[20];
  string root_state, child_state;
  int noise;
  initial begin
    r.srandom(73); r.child.srandom(73);
    repeat (6000) begin
      if (!r.randomize()) $fatal(1, "joint solve failed");
      count[{r.value, r.child.value}]++;
    end

    if (count[1] || count[0] < 1800 || count[0] > 2200
        || count[2] < 1800 || count[2] > 2200
        || count[3] < 1800 || count[3] > 2200)
      $fatal(1, "joint tuples are not uniform");
    root_state = r.get_randstate(); child_state = r.child.get_randstate();
    for (int i=0; i<20; ++i) begin
      if (!r.randomize()) $fatal(1, "replay setup failed");
      replay[i] = {r.value, r.child.value};
    end
    r.set_randstate(root_state); r.child.set_randstate(child_state);
    for (int i=0; i<20; ++i) begin
      noise = $urandom;
      if (!unrelated.randomize()) $fatal(1, "unrelated solve failed");
      if (!r.randomize() || {r.value, r.child.value} != replay[i])
        $fatal(1, "joint RNG replay depends on unrelated calls");
    end
    $display("PASSED");
  end
endmodule
