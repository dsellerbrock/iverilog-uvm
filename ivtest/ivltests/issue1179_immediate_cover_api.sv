module top;
  int hits;
  initial begin : vpi_process
    // Each label creates a named block around its immediate cover statement.
    true_cover_one: cover (1'b1) hits++;
    true_cover_two: cover (1'b1) hits++;
    false_cover: cover (1'b0) hits++;
    if (hits != 2 || !$immediate_cover_api_check())
      $fatal(1, "hits=%0d immediate cover API mismatch", hits);
    $display("PASS immediate cover API\nPASSED");
    $finish(0);
  end
endmodule
