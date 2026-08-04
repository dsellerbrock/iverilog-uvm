// A `foreach' constraint item whose iterated target is hierarchical --
// foreach (array_name[prefix].member_name[loop_var]) -- used to be a hard
// syntax error: the prefix bracket was originally parsed as `expression',
// but a bare identifier there (the common real-world shape, e.g. a
// `device_id' selecting one element before iterating its `addr_ranges'
// member) is indistinguishable from a fresh loop-variable declaration with
// one token of lookahead, so the parser always reduced it to a loop
// variable and the `.member_name[...]' continuation could never be
// reached (the identical ambiguity already root-caused for the
// plain-statement foreach of the same shape, ledger G65).
//
// The grammar now parses the prefix through `loop_variables' -- the same
// nonterminal used for an ordinary loop-variable list -- and the
// constraint-IR generator treats those names as references to
// already-declared variables, not fresh declarations. This test only
// verifies the construct now PARSES and that randomize() still completes
// normally (with the hierarchical-target item dropped and reported via a
// compile-progress warning, since resolving `array_name' against a
// non-rand lookup table is a separate, larger gap -- see
// sv_randomize_with_unresolvable_dropped.v for that same drop-loudly
// behavior on a simpler non-hierarchical foreach).
class dev_t;
  rand int unsigned size[3];
endclass

class item;
  rand int unsigned idx;
  rand int unsigned device_id;

  dev_t lookup[4];

  function new();
    foreach (lookup[i]) lookup[i] = new;
  endfunction

  task go();
    void'(randomize() with {
        device_id inside {[0:3]};
        foreach (lookup[device_id].size[i]) {
          lookup[device_id].size[i] < 10;
        }
    });
  endtask
endclass

module main;
  initial begin
    item it;
    it = new;
    it.go();
    if (it.device_id < 0 || it.device_id > 3) begin
      $display("FAILED device_id=%0d out of the resolvable range", it.device_id);
      $finish;
    end
    $display("PASSED");
  end
endmodule
