package rootless_types;
  typedef int word_t;

  class base;
    virtual function word_t value();
      return 1;
    endfunction
  endclass
endpackage

import rootless_types::*;

class derived extends base;
  function word_t value();
    return 2;
  endfunction
endclass

class constrained;
  rand int value;
  extern constraint zero;
endclass

constraint constrained::zero { value == 0; }
