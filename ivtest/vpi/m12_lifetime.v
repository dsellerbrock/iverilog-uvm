// M12-8: VPI handle lifetime/free behavior audit. Exercises the M12
// handle families (class member, nested member, covergroup item/bin)
// for: stable handle identity across repeated vpi_iterate (no
// per-call leak), iterator auto-free on scan exhaustion, explicit
// vpi_free_object being safe (no double-free of container-owned or
// cached handles), and use-after-object-null (a handle whose backing
// object is dropped reads safely rather than crashing).
module top;
  class Leaf; int v = 5; endclass
  class Node;
    Leaf leaf;
    int id = 9;
    function new; leaf = new; endfunction
  endclass
  Node n;

  bit [1:0] a;
  covergroup cg;
    cp_a: coverpoint a { bins x[] = {0,1,2,3}; }
  endgroup
  cg c1 = new;

  initial begin
    n = new;
    a = 1; c1.sample();
    $m12lt_probe;          // iterate members/items twice, check stability
    n = null;              // drop the object; the deep handle must stay safe
    $m12lt_after_null;
    $finish(0);
  end
endmodule
