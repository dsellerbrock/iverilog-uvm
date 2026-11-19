// Distinct declarations are ambiguous, and a realized import is locally visible.
package wild_first3361;
  checker c; endchecker
endpackage

package wild_second3361;
  checker c; endchecker
endpackage

module issue3361_ambiguous;
  import wild_first3361::*;
  import wild_second3361::*;
  c u();
endmodule

module issue3361_conflict;
  import wild_first3361::*;
  if (1) begin : gen_scope
    c u();
  end
  logic c;
endmodule
