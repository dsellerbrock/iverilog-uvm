// IEEE 1800-2017 18.6, 18.8 and 18.9 define these as built-in class
// methods.  User class declarations cannot replace or override them.
class bad_randomize;
  function int randomize;
    return 1;
  endfunction
endclass

class bad_rand_mode;
  function int rand_mode;
    return 1;
  endfunction
endclass

class bad_constraint_mode;
  function int constraint_mode;
    return 1;
  endfunction
endclass

module test;
endmodule
