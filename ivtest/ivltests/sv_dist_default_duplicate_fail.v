class duplicate_default_item;
  rand bit value;
  constraint c { value dist {default :/ 1, default :/ 2}; }
endclass
