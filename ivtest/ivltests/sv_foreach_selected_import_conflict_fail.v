// IEEE 1800-2017/2023 12.7.3 and 26.3: record prefix use before the loop scope.
package foreach_shadow_a;
  int chosen = 0;
endpackage
package foreach_shadow_b;
  int chosen = 1;
endpackage
class foreach_terminal_row;
  int data[1];
endclass
module main;
  import foreach_shadow_a::*;
  import foreach_shadow_b::*;
  foreach_terminal_row rows[1];
  // Negative: prefix lookup is ambiguous even though the terminal
  // iterator later uses the same name.
  initial foreach (rows[chosen].data[chosen]) begin end
endmodule
