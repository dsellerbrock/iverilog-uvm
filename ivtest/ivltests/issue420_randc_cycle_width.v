class extended_cycle_item;
  randc bit [20:0] value;
  rand bit marker;
  bit make_other_constraint_unsatisfiable;

  constraint marker_gate {
    if (make_other_constraint_unsatisfiable) marker == 1'b0;
    if (make_other_constraint_unsatisfiable) marker == 1'b1;
  }
endclass

class boundary_cycle_item;
  randc bit [31:0] value;
endclass

class over_cap_cycle_item;
  randc bit [20:0] value;
  constraint legal_values { value inside {[0:2048]}; }
endclass

module test;
  initial begin
    extended_cycle_item extended;
    boundary_cycle_item boundary;
    over_cap_cycle_item over_cap;
    bit [2097151:0] seen;
    bit [31:0] boundary_values[128];
    bit [20:0] previous;

    extended = new;
    boundary = new;
    over_cap = new;
    extended.srandom(32'h420021);
    boundary.srandom(32'h420032);
    over_cap.srandom(32'h420801);
    seen = '0;

    for (int unsigned i = 0; i < 4096; i++) begin
      if (i == 2048) begin
        previous = extended.value;
        extended.make_other_constraint_unsatisfiable = 1'b1;
        if (extended.randomize())
          $fatal(1, "unsatisfiable call unexpectedly succeeded");
        if (extended.value !== previous)
          $fatal(1, "failed randomize changed the randc value");
        extended.make_other_constraint_unsatisfiable = 1'b0;
      end
      if (!extended.randomize())
        $fatal(1, "21-bit randc failed at draw %0d", i);
      if (seen[extended.value])
        $fatal(1, "21-bit randc repeated at draw %0d", i);
      seen[extended.value] = 1'b1;
    end

    for (int unsigned i = 0; i < 128; i++) begin
      if (!boundary.randomize())
        $fatal(1, "32-bit randc failed at draw %0d", i);
      for (int unsigned j = 0; j < i; j++)
        if (boundary_values[j] == boundary.value)
          $fatal(1, "32-bit randc repeated at draw %0d", i);
      boundary_values[i] = boundary.value;
    end

    if (over_cap.randomize())
      $fatal(1, "2,049-value constrained randc unexpectedly succeeded");

    $display("PASS issue420 randc exact wide cycle");
    $finish;
  end
endmodule
