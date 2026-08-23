module sv_force_partial_live_overlap;
  logic [15:0] value;
  logic [7:0] older_source;
  logic [7:0] newer_source;
  logic [15:0] wide_source;

  task automatic expect_value(input logic [15:0] expected,
                              input int step);
    if (value !== expected) begin
      $display("FAILED step=%0d actual=%h expected=%h",
               step, value, expected);
      $finish;
    end
  endtask

  initial begin
    value = 16'h1234;
    older_source = 8'ha5;
    force value[11:4] = older_source;
    #0 expect_value(16'h1a54, 1);

    // A procedural write changes the retained value while the force mask
    // remains visible. The force RHS remains a live continuous source.
    value = 16'hdead;
    #0 expect_value(16'hda5d, 2);
    older_source = 8'h3c;
    #0 expect_value(16'hd3cd, 3);

    // A newer force permanently supersedes only its overlapping bits.
    newer_source = 8'h96;
    force value[7:0] = newer_source;
    #0 expect_value(16'hd396, 4);
    older_source = 8'he1;
    #0 expect_value(16'hde96, 5);
    newer_source = 8'h47;
    #0 expect_value(16'hde47, 6);

    // Releasing the newer high nibble retains its last visible value. It
    // must not reconnect the older source that previously owned the overlap.
    release value[7:4];
    newer_source = 8'ha2;
    older_source = 8'hc5;
    #0 expect_value(16'hdc42, 7);

    // Releasing variable bits retains their last forced values until a
    // subsequent procedural write. Disjoint newer ownership remains live.
    release value[11:8];
    older_source = 8'h19;
    #0 expect_value(16'hdc42, 8);
    release value[3:0];
    newer_source = 8'h0f;
    #0 expect_value(16'hdc42, 9);

    value = 16'h1357;
    #0 expect_value(16'h1357, 10);

    // Keep the force source wider than the destination slice. Partial writes
    // outside the linked low byte must not disturb its cached value, while
    // partial writes inside that byte must update only the touched bits.
    value = 16'hbe00;
    wide_source = 16'h12a5;
    force value[7:0] = wide_source;
    #0 expect_value(16'hbea5, 11);
    wide_source[15:8] = 8'hfe;
    #0 expect_value(16'hbea5, 12);
    wide_source[3:0] = 4'hc;
    #0 expect_value(16'hbeac, 13);
    wide_source[11:8] = 4'h0;
    #0 expect_value(16'hbeac, 14);
    wide_source[7:4] = 4'h3;
    #0 expect_value(16'hbe3c, 15);
    release value[7:0];
    wide_source[3:0] = 4'h1;
    #0 expect_value(16'hbe3c, 16);

    $display("PASSED");
  end
endmodule
