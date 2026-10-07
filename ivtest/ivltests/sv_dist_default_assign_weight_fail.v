class invalid_default_assign_weight;
  rand bit value;
  constraint c { value dist {default := 1}; }
endclass
