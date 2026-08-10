// A compilation-unit diagnostic precedes both root-module scope passes.
// Neither root may synthesize another error merely because one already exists.
class bad_preexisting_randomize;
  function int randomize;
    return 1;
  endfunction
endclass

module root_a;
endmodule

module root_b;
endmodule
