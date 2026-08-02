class rand_assoc_child;
  rand bit [7:0] value;
  constraint value_c { value == 8'h5a; }
endclass

class rand_assoc_parent;
  rand rand_assoc_child children[string];
endclass

module rand_assoc_object_recursive_test;
  initial begin
    rand_assoc_parent parent;
    parent = new;
    parent.children["first"] = new;
    parent.children["second"] = new;

    if (!parent.randomize())
      $fatal(1, "parent randomization failed");
    if (parent.children.size() != 2 ||
        !parent.children.exists("first") ||
        !parent.children.exists("second"))
      $fatal(1, "randomization changed associative-array keys");
    if (parent.children["first"].value != 8'h5a ||
        parent.children["second"].value != 8'h5a)
      $fatal(1, "associative-array child constraints were not solved");

    $display("PASS: rand associative-object elements recurse");
  end
endmodule
