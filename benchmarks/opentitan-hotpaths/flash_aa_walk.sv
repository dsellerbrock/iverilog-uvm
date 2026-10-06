module top;
  // OpenTitan's flash DV address type is bit [TL_AW-1:0] (32 bits in
  // Earlgrey). Keep the associative-array key as a packed 2-state vector;
  // an integer index does not preserve that key-type fidelity.
  typedef bit [31:0] addr_t;
  int unsigned flash[addr_t];
  int unsigned entries;
  addr_t key;
  int unsigned i;

  initial begin
    if (!$value$plusargs("entries=%d", entries))
      entries = 4096;
    if (entries == 0)
      $fatal(1, "entries must be positive");

    $flash_timer_start();
    for (i = 0; i < entries; i++)
      flash[i] = i;
    $flash_timer_population_done();

    if (!flash.first(key))
      $fatal(1, "first failed for nonempty array");
    for (i = 0; i < entries; i++) begin
      if (key != i)
        $fatal(1, "walk mismatch at %0d: got %0d", i, key);
      if (i + 1 < entries) begin
        if (!flash.next(key))
          $fatal(1, "next ended at %0d of %0d", i, entries);
      end else if (flash.next(key)) begin
        $fatal(1, "next continued after final key");
      end
    end
    $flash_timer_walk_done();
    $display("PASS entries=%0d traversed=%0d", entries, i);
  end
endmodule
