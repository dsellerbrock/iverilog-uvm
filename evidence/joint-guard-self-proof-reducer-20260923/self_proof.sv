class self_proof_leaf;
  rand bit peer;
endclass

class self_proof_root;
  rand self_proof_leaf child;
  rand bit gate, value, weight;
  function new(); child = new; gate = 1; value = 0; weight = 0; endfunction
  constraint c {
    value == 0;
    child.peer == value;
    if (gate) value dist {0 := weight, 1 := 1};
  }
endclass

module top;
  self_proof_root root = new;
  initial begin
    if (root.randomize())
      $display("UNEXPECTED_SUCCESS gate=%0d value=%0d weight=%0d", root.gate, root.value, root.weight);
    else
      $display("REJECTED gate=%0d value=%0d weight=%0d", root.gate, root.value, root.weight);
    $finish(0);
  end
endmodule
