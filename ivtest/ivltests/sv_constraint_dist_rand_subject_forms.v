// IEEE 1800-2017 §18.5.4 and IEEE 1800-2023 §18.5.3.
class dist_rand_child;
  rand bit [3:0] r;
endclass

class dist_rand_countones_subject;
  rand bit [7:0] r;
  constraint one_set_bit { $countones(r) dist {1 := 1}; }
endclass

class dist_rand_base;
  rand bit [3:0] inherited;
endclass

class dist_rand_exact extends dist_rand_base;
  rand bit [3:0] direct;
  rand bit [3:0] explicit_this;
  rand bit [3:0] soft_value;

  constraint exact_values {
    direct dist {7 := 1};
    this.explicit_this dist {8 := 1};
    inherited dist {6 := 1};
    soft soft_value dist {9 := 1};
  }
endclass

class dist_rand_subject_forms extends dist_rand_base;
  typedef struct packed { bit [3:0] field; } packed_t;
  typedef struct { rand bit [3:0] field; } unpacked_t;
  rand bit [3:0] direct;
  rand bit [3:0] explicit_this;
  rand bit [3:0] mixed;
  rand bit [3:0] soft_value;
  rand bit [3:0] array[2];
  rand bit [3:0] rand_fixed_array[4];
  rand packed_t packed_value;
  rand unpacked_t unpacked_value;
  rand dist_rand_child child;
  bit [3:0] state;

  function new();
    child = new;
    state = 1;
  endfunction

  function bit [3:0] state_value();
    return state;
  endfunction

  constraint dist_forms {
    direct dist {1 := 1};
    this.explicit_this dist {2 := 1};
    inherited dist {3 := 1};
    child.r dist {4 := 1};
    packed_value.field dist {5 := 1};
    array[0] dist {6 := 1};
    foreach (array[i]) array[i] dist {6 := 1};
    (mixed + state) dist {7 := 1};
    // Compile-only: invoking this with a rand class handle reaches the
    // explicit unsupported runtime path documented in DD-129.
    (mixed + state_value()) dist {7 := 1};
    unpacked_value.field dist {5 := 1};
    foreach (rand_fixed_array[i]) rand_fixed_array[i] dist {5 := 1};
    soft soft_value dist {8 := 1};
  }
endclass

class dist_rand_unpacked_member_subject;
  typedef struct { rand bit [3:0] field; } unpacked_t;
  rand unpacked_t value;
  constraint member_dist { value.field dist {5 := 1}; }
endclass

class dist_rand_fixed_array_subject;
  rand bit [3:0] value[4];
  constraint element_dist { foreach (value[i]) value[i] dist {5 := 1}; }
endclass

module main;
  int value;
  int a;
  int b;
  dist_rand_subject_forms item = new;
  dist_rand_unpacked_member_subject member_item = new;
  dist_rand_fixed_array_subject fixed_array_item = new;
  dist_rand_exact exact_item = new;
  dist_rand_countones_subject countones_item = new;

  initial begin
    // Compile all subject forms, including shapes whose runtime solver support
    // is covered by the existing dist regression suite.
    if (0) begin
      void'(item.randomize());
      void'(std::randomize(value) with { value dist {9 := 1}; });
      void'(std::randomize(a, b) with { (a + b) dist {10 := 1}; });
    end

    item.dist_forms.constraint_mode(0);
    if (!member_item.randomize() || member_item.value.field != 5)
      $fatal(1, "rand unpacked-struct member dist failed");
    if (!fixed_array_item.randomize())
      $fatal(1, "rand fixed-array dist failed");
    foreach (fixed_array_item.value[i])
      if (fixed_array_item.value[i] != 5)
        $fatal(1, "rand fixed-array dist failed");

    if (!exact_item.randomize()
        || exact_item.direct != 7 || exact_item.explicit_this != 8
        || exact_item.inherited != 6 || exact_item.soft_value != 9)
      $fatal(1, "rand dist exact-value control failed");

    repeat (50)
      if (!countones_item.randomize() || $countones(countones_item.r) != 1)
        $fatal(1, "$countones rand dist did not select one set bit");

    $display("PASSED");
  end
endmodule
