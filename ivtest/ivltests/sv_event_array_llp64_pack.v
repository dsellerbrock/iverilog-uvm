// IEEE 1800-2017 6.20 / 15.5: the VVP immediate for an event-array
// element carries a 32-bit base and 32-bit count.  The second array has
// a nonzero base, so truncating that immediate on an LLP64 host aliases
// its element with the first array's element.
module main;
  event a[1];
  event z[1];
  bit a_block, z_block, a_nb, z_nb;
  int fails;

  initial begin @a[0]; a_block = 1; end
  initial begin @z[0]; z_block = 1; end
  initial begin #2; @a[0]; a_nb = 1; end
  initial begin #2; @z[0]; z_nb = 1; end

  initial begin
    #1 ->z[0];
    if (!z[0].triggered || a[0].triggered) begin
      fails++;
      $display("FAILED triggered alias a=%0d z=%0d",
               a[0].triggered, z[0].triggered);
    end

    #1;
    if (a_block || !z_block) begin
      fails++;
      $display("FAILED blocking alias a=%0d z=%0d", a_block, z_block);
    end

    #1 ->>z[0];
    #1;
    if (a_nb || !z_nb) begin
      fails++;
      $display("FAILED nonblocking alias a=%0d z=%0d", a_nb, z_nb);
    end

    if (fails == 0) $display("PASSED");
    else $display("FAILED (%0d)", fails);
    $finish(0);
  end
endmodule
