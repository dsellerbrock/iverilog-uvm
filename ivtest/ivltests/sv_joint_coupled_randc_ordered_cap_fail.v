// A randc leaf coupled into an ordered solve whose joint solution set (2048
// tuples) is larger than the solver's tuple-enumeration cap. This row used
// to assert that randomize() fails at the cap; it must succeed (#2228).
// IEEE 1800-2023 18.5.9: "a 'solve...before...' constraint does not change
// the solution space and, therefore, cannot cause the solver to fail."
// 18.4.2: "A set of constraints that includes both rand and randc variables
// shall be solved so that the randc variables are solved first, and this can
// sometimes cause randomize() to fail" -- not here: wide[0] == leaf.cyc is
// satisfiable for either value of the randc bit.
class l111_cap_leaf; randc bit cyc; endclass
class l111_cap_item; rand bit [10:0] wide;rand bit dep;rand l111_cap_leaf leaf;
 constraint l {wide[0]==leaf.cyc;dep==wide[0];} constraint o {solve wide before dep;}
 function new;leaf=new;endfunction endclass
module sv_joint_coupled_randc_ordered_cap_fail;
  initial begin
    l111_cap_item t;
    int seen[2];
    t=new;
    // Four complete randc cycles: each value of cyc exactly four times.
    repeat (8) begin
      if (!t.randomize()) $fatal(1, "randomize() failed past the cap");
      if (t.wide[0] != t.leaf.cyc || t.dep != t.wide[0]) $fatal(1, "constraint violated");
      seen[t.leaf.cyc]++;
    end
    if (seen[0] != 4 || seen[1] != 4) $fatal(1, "randc cycle %0d/%0d", seen[0], seen[1]);
    $display("PASSED");
    $finish(0);
  end
endmodule
