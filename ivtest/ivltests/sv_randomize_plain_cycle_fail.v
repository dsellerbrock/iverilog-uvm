// IEEE 1800-2017 18.5.10 / 1800-2023 18.5.9: ordering must be acyclic.
class cyclic_plain;
  rand bit a, b;
  constraint c { solve a before b; solve b before a; a != b; }
endclass

module main;
  cyclic_plain obj = new;
  initial begin
    if (obj.randomize()) $fatal(1, "cyclic solve-before ordering succeeded");
    $display("PASSED");
  end
endmodule
