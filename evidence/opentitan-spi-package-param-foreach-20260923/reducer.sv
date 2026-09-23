package spi_reducer_pkg;
  parameter string NAMES[] = {"access", "status", "hash"};

  class coverage_model;
    int seen;

    function new();
      foreach (NAMES[i]) begin
        if (NAMES[i] == "") $fatal(1, "empty name");
        seen++;
      end
    endfunction
  endclass
endpackage

module top;
  spi_reducer_pkg::coverage_model model;
  initial begin
    model = new();
    if (model.seen != 3) $fatal(1, "foreach saw %0d items", model.seen);
    $display("PASS package parameter foreach");
  end
endmodule
