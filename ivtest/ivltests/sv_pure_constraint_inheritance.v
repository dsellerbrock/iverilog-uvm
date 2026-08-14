virtual class base_c;
  pure constraint fixed_value;
endclass

virtual class intermediate_c extends base_c;
endclass

class concrete_c extends intermediate_c;
  rand int value;
  constraint fixed_value { value == 7; }
endclass

virtual class implemented_virtual_c extends base_c;
  rand int inherited_value;
  constraint fixed_value { inherited_value == 9; }
endclass

class inherited_concrete_c extends implemented_virtual_c;
endclass

virtual class generic_base_c #(int EXPECTED = 11);
  pure constraint generic_fixed_value;
endclass

class generic_concrete_c #(int EXPECTED = 11)
    extends generic_base_c #(EXPECTED);
  rand int generic_value;
  constraint generic_fixed_value { generic_value == EXPECTED; }
endclass

class inherited_generic_base_c #(int EXPECTED = 15);
  rand int inherited_generic_value;
  constraint inherited_generic_fixed {
    inherited_generic_value == EXPECTED;
  }
endclass

class inherited_generic_derived_c #(int EXPECTED = 15)
    extends inherited_generic_base_c #(EXPECTED);
endclass

typedef enum bit [1:0] {
  ENUM_ZERO = 2'b00,
  ENUM_TWO = 2'b10
} sparse_enum_t;

class specialized_enum_c #(int TAG = 0);
  rand sparse_enum_t enum_value;
endclass

module test;
  concrete_c item;
  inherited_concrete_c inherited_item;
  generic_concrete_c #() default_item;
  generic_concrete_c #(13) nondefault_item;
  inherited_generic_derived_c #(17) inherited_generic_item;
  specialized_enum_c #() default_enum_item;
  specialized_enum_c #(1) nondefault_enum_item;

  initial begin
    item = new;
    inherited_item = new;
    default_item = new;
    nondefault_item = new;
    inherited_generic_item = new;
    default_enum_item = new;
    nondefault_enum_item = new;
    if (!item.randomize())
      $fatal(1, "pure-constraint implementation did not solve");
    if (item.value != 7)
      $fatal(1, "inherited pure constraint implementation was lost: %0d",
             item.value);
    if (!inherited_item.randomize() || inherited_item.inherited_value != 9)
      $fatal(1, "virtual intermediate implementation was lost: %0d",
             inherited_item.inherited_value);
    if (!default_item.randomize() || default_item.generic_value != 11)
      $fatal(1, "default specialization pure implementation failed: %0d",
             default_item.generic_value);
    if (!nondefault_item.randomize() || nondefault_item.generic_value != 13)
      $fatal(1, "nondefault specialization pure implementation failed: %0d",
             nondefault_item.generic_value);
    if (!inherited_generic_item.randomize()
        || inherited_generic_item.inherited_generic_value != 17)
      $fatal(1, "specialized inherited constraint failed: %0d",
             inherited_generic_item.inherited_generic_value);
    if (default_enum_item.randomize() with {
          enum_value == sparse_enum_t'(1);
        })
      $fatal(1, "default specialization lost synthesized enum constraint");
    if (nondefault_enum_item.randomize() with {
          enum_value == sparse_enum_t'(1);
        })
      $fatal(1, "nondefault specialization lost synthesized enum constraint");
    $display("PASSED");
  end
endmodule
