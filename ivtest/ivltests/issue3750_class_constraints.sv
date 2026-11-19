package constraint_pkg;
  typedef enum bit [1:0] {ZERO = 0, TWO = 2} choice_t;

  virtual class Base #(int Bound = 4);
    rand int value;
    rand choice_t choice;
    constraint z_limit { value == Bound; }
    pure constraint p_pure;
    constraint empty_block {}
    extern static constraint m_extern;
    constraint k_implicit;
    constraint a_range { value inside {[0:15]}; }
    constraint b_empty_prototype;
  endclass

  // The bodies appear in reverse order from their prototypes.
  constraint Base::k_implicit { value < 12; }
  static constraint Base::m_extern { value > 0; }

  class Derived #(int N = 4) extends Base#(N);
    constraint z_limit { value == N + 1; }
    constraint p_pure { choice == TWO; }
  endclass

  class Inherits extends Derived#(6);
  endclass
endpackage

module top;
  constraint_pkg::Derived#(6) first;
  constraint_pkg::Derived#(8) second;
  constraint_pkg::Inherits inherits;

  initial begin
    first = new;
    second = new;
    if (first.randomize() with { value == 0; })
      $fatal(1, "a conflicting inline constraint was ignored");
    if (!first.randomize() with { value == 7; } ||
        first.value != 7 || first.choice != constraint_pkg::TWO)
      $fatal(1, "first specialization did not honor the inline constraint");
    if (!second.randomize() with { value == 9; } ||
        second.value != 9 || second.choice != constraint_pkg::TWO)
      $fatal(1, "second specialization did not honor the inline constraint");
    $check_class_constraints;
  end
endmodule
