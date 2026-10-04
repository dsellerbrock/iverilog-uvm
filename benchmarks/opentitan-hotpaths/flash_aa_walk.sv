module top;
  int unsigned flash[int unsigned];
  int unsigned entries;
  int unsigned key;
  int unsigned i;

  initial begin
    if (!$value$plusargs("entries=%d", entries))
      entries = 4096;
    if (entries == 0)
      $fatal(1, "entries must be positive");

    for (i = 0; i < entries; i++)
      flash[i] = i;

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
    $display("PASS entries=%0d traversed=%0d", entries, i);
  end
endmodule
