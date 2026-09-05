// IEEE 1800-2017/2023 12.7.3 and 26.3: record prefix use before the loop scope.
package foreach_late_pkg;
  int chosen = 1;
endpackage
class foreach_late_row;
  int data[1];
endclass
module main;
  import foreach_late_pkg::*;
  foreach_late_row rows[2];
  initial foreach (rows[chosen].data[chosen]) begin
    static int chosen = 0;
    assert (chosen == 0);
  end
  // Negative: the earlier header used the package-imported chosen.
  int chosen;
endmodule
