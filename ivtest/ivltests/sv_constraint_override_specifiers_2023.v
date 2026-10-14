class constraint_override_base;
  rand bit [1:0] value;
  constraint :initial selected { value == 1; }
  constraint :initial :final inherited_bound { value inside {[0:2]}; }
endclass

class constraint_override_derived extends constraint_override_base;
  constraint :extends :final selected { value == 2; }
endclass

virtual class constraint_override_pure_base;
  rand bit value;
  pure constraint :initial required;
endclass

class constraint_override_pure_derived extends constraint_override_pure_base;
  constraint :extends required { value == 1; }
endclass

class constraint_override_extern_base;
  rand bit [1:0] value;
  constraint :initial selected { value == 0; }
endclass

class constraint_override_extern_derived extends constraint_override_extern_base;
  extern constraint :extends selected;
endclass

constraint :extends constraint_override_extern_derived::selected { value == 3; }

module test;
  constraint_override_derived item;
  constraint_override_pure_derived pure_item;
  constraint_override_extern_derived external_item;

  initial begin
    item = new;
    if (!item.randomize() || item.value != 2)
      $fatal(1, "constraint :extends did not replace the inherited block");

    pure_item = new;
    if (!pure_item.randomize() || pure_item.value != 1)
      $fatal(1, "constraint :extends did not implement the inherited pure block");

    external_item = new;
    if (!external_item.randomize() || external_item.value != 3)
      $fatal(1, "matching extern constraint specifiers did not replace the base block");

    $display("PASSED");
  end
endmodule
