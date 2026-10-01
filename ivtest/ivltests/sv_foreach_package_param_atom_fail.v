// IEEE 1800-2017/2023 12.7.3: built-in integral atoms are scalar foreach
// targets even when their implementation types carry a packed bit range.
package atom_foreach_pkg;
  parameter int COUNT = 7;
  parameter integer IC = 7;
  parameter byte B = 8'h5a;
endpackage

module main;
  initial begin
    foreach (atom_foreach_pkg::COUNT[i]) $display("INVALID COUNT %0d", i);
    foreach (atom_foreach_pkg::IC[j]) $display("INVALID IC %0d", j);
    foreach (atom_foreach_pkg::B[k]) $display("INVALID B %0d", k);
  end
endmodule
