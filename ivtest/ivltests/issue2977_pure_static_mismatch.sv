virtual class base_t;
  pure static constraint c;
endclass
class derived_t extends base_t;
  constraint c { 1; }
endclass
virtual class bad_t extends base_t;
  pure constraint c;
endclass
class bad_derived_t extends bad_t;
  constraint c { 1; }
endclass
module top;
  derived_t item;
  bad_derived_t other;
endmodule
