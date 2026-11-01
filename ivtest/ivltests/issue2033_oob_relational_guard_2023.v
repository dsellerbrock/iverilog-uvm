class relational_oob;
  rand bit s;
  rand bit v[$];
  constraint c { v.size() == 0; v[0] <= s; }
endclass

class equality_oob;
  rand bit s;
  rand bit v[$];
  constraint c { v.size() == 0; v[0] == s; }
endclass

class guarded_oob;
  rand bit s;
  rand bit v[$];
  bit en = 0;
  constraint c { v.size() == 0; if (en) v[0] <= s; }
endclass

module test;
  relational_oob rel;
  equality_oob eq;
  guarded_oob guarded;
  initial begin
    rel = new;
    eq = new;
    guarded = new;
    if (rel.randomize() !== 0) $fatal(1, "unguarded relational OOB accepted");
    if (eq.randomize() !== 0) $fatal(1, "unguarded equality OOB accepted");
    if (!guarded.randomize()) $fatal(1, "false guard did not suppress OOB");
    $display("PASSED");
  end
endmodule
