// IEEE 1800-2017 18.5.4/18.5.6; 2023 clause 18 (dist: 18.5.3).
// OpenTitan AES uses an unbraced implication before a weighted dist.
// The implication guards the distribution on its consequent.
class implied_dist_item;
  rand bit guard;
  rand bit [1:0] value;
  constraint c { guard -> value dist {[0:1] := 1, 2 :/ 0}; }
endclass

class implied_per_range_item;
  rand bit guard;
  rand bit [1:0] value;
  constraint c { guard -> value dist {[0:1] :/ 1, 2 := 0}; }
endclass

class neighboring_item;
  rand bit guard;
  rand bit ordinary;
  rand bit grouped;
  constraint c {
    guard -> ordinary == 1;
    guard -> { grouped dist {0 := 1, 1 := 0}; }
  }
endclass

class soft_item;
  rand bit guard;
  rand bit value;
  constraint c { guard -> soft value dist {0 :/ 1, 1 :/ 0}; }
endclass

class chained_item;
  rand bit a, b, c;
  constraint k { a -> b -> c; }
endclass

class nested_dist_item;
  rand bit a, b, value;
  constraint k { a -> b -> value dist {0 :/ 1, 1 :/ 0}; }
endclass

class nested_soft_dist_item;
  rand bit a, b, value;
  constraint k { a -> b -> soft value dist {0 :/ 1, 1 :/ 0}; }
endclass

module test;
  implied_dist_item assign_weight;
  implied_per_range_item range_weight;
  neighboring_item neighbor;
  soft_item preference;
  chained_item chained;
  nested_dist_item nested;
  nested_soft_dist_item nested_soft;
  initial begin
    assign_weight = new;
    if (!assign_weight.randomize() with {guard == 0; value == 3;}) $fatal(1, "inactive := distribution");
    if (!assign_weight.randomize() with {guard == 1; value == 0;}) $fatal(1, "active := zero");
    if (!assign_weight.randomize() with {guard == 1; value == 1;}) $fatal(1, "active := one");
    if (assign_weight.randomize() with {guard == 1; value == 2;}) $fatal(1, "active := conflict");
    if (assign_weight.value != 1) $fatal(1, "failed randomize changed prior value");

    range_weight = new;
    if (!range_weight.randomize() with {guard == 0; value == 3;}) $fatal(1, "inactive :/ distribution");
    if (!range_weight.randomize() with {guard == 1; value == 0;}) $fatal(1, "active :/ zero");
    if (!range_weight.randomize() with {guard == 1; value == 1;}) $fatal(1, "active :/ one");
    if (range_weight.randomize() with {guard == 1; value == 2;}) $fatal(1, "active :/ conflict");

    neighbor = new;
    if (!neighbor.randomize() with {guard == 0; ordinary == 0; grouped == 1;}) $fatal(1, "neighbor inactive");
    if (!neighbor.randomize() with {guard == 1;}) $fatal(1, "neighbor active");
    if (neighbor.ordinary != 1 || neighbor.grouped != 0) $fatal(1, "neighbor values");
    if (neighbor.randomize() with {guard == 1; ordinary == 0;}) $fatal(1, "ordinary conflict");
    if (neighbor.randomize() with {guard == 1; grouped == 1;}) $fatal(1, "grouped conflict");

    preference = new;
    if (!preference.randomize() with {guard == 0; value == 1;}) $fatal(1, "soft inactive");
    if (!preference.randomize() with {guard == 1; value == 1;}) $fatal(1, "soft override");
    if (!preference.randomize() with {guard == 1;}) $fatal(1, "soft active");
    if (preference.value != 0) $fatal(1, "soft preference ignored");

    chained = new;
    if (!chained.randomize() with {a == 0; b == 0; c == 0;}) $fatal(1, "chained implication association");
    if (!chained.randomize() with {a == 0; b == 1; c == 0;}) $fatal(1, "chained implication right association");
    if (chained.randomize() with {a == 1; b == 1; c == 0;}) $fatal(1, "chained implication conflict");

    nested = new;
    if (!nested.randomize() with {a == 0; b == 1; value == 1;}) $fatal(1, "outer nested guard inactive");
    if (!nested.randomize() with {a == 1; b == 0; value == 1;}) $fatal(1, "inner nested guard inactive");
    if (!nested.randomize() with {a == 1; b == 1; value == 0;}) $fatal(1, "nested distribution active");
    if (nested.randomize() with {a == 1; b == 1; value == 1;}) $fatal(1, "nested hard conflict");

    nested_soft = new;
    if (!nested_soft.randomize() with {a == 0; b == 1; value == 1;}) $fatal(1, "outer nested soft guard inactive");
    if (!nested_soft.randomize() with {a == 1; b == 0; value == 1;}) $fatal(1, "inner nested soft guard inactive");
    if (!nested_soft.randomize() with {a == 1; b == 1; value == 1;}) $fatal(1, "nested soft override");
    if (!nested_soft.randomize() with {a == 1; b == 1;}) $fatal(1, "nested soft active");
    if (nested_soft.value != 0) $fatal(1, "nested soft preference ignored");
    $display("PASSED");
  end
endmodule
