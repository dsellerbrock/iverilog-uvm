// IEEE 1800-2017 18.5.8.1/18.5.9; 1800-2023 18.5.7.1/18.5.8.
class issue2120_leaf;
  rand bit [3:0] v;
endclass

class issue2120_assoc;
  rand issue2120_leaf ai[int];
  constraint c {
    ai[2].v == 2;
    foreach (ai[k]) ai[k].v == k;
  }
endclass

class issue2120_queue;
  rand issue2120_leaf aq[$];
  constraint c {
    aq[0].v == 0;
    foreach (aq[k]) aq[k].v == k;
  }
endclass

module main;
  issue2120_assoc assoc;
  issue2120_queue queue;
  issue2120_leaf first, second;
  initial begin
    assoc = new;
    queue = new;
    first = new;
    second = new;
    assoc.ai[2] = first;
    queue.aq.push_back(first);
    queue.aq.push_back(second);
    if (!assoc.randomize() || assoc.ai[2].v != 2)
      $fatal(1, "associative-array class-handle constraint failed");
    if (!queue.randomize() || queue.aq[0].v != 0 || queue.aq[1].v != 1)
      $fatal(1, "queue class-handle constraint failed");
    $display("PASSED");
  end
endmodule
