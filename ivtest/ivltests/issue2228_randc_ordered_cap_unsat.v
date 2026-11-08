// #2228 companion: the over-cap ordered randc path must still report an
// unsatisfiable set. IEEE 1800-2023 18.4.2: the randc variables are solved
// first, "and this can sometimes cause randomize() to fail". Here the set
// is unsatisfiable for every value of the randc bit (dep == wide[0] ==
// leaf.cyc, but dep != leaf.cyc), so randomize() returns 0 and leaves the
// values as they were (18.6.3), even though the joint domain is past the
// solver's enumeration cap.
class unsat_leaf; randc bit cyc; endclass
class unsat_item; rand bit [10:0] wide; rand bit dep; rand unsat_leaf leaf;
  constraint l { wide[0] == leaf.cyc; dep == wide[0]; dep != leaf.cyc; }
  constraint o { solve wide before dep; }
  function new; leaf = new; endfunction endclass
module issue2228_randc_ordered_cap_unsat;
  unsat_item t = new;
  initial begin
    t.wide = 11'h2a5;
    t.dep = 1;
    if (t.randomize()) $display("FAILED: an unsatisfiable set randomized");
    else if (t.wide != 11'h2a5 || t.dep != 1) $display("FAILED: a failed call changed the values");
    else $display("PASSED");
  end
endmodule
