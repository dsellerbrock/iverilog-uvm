// IEEE 1800-2023 21.3.3: the output variable of $swrite and $sformat may be
// an unpacked array of byte. Characters go from the left bound to the right
// bound, by the string literal assignment rules of 5.9 (zero filled, cut at
// the right bound).
module top;
  byte up[0:4];
  byte down[6:0];
  byte tiny[0:2];
  byte ref_down[6:0] = "HELLO";
  int errors = 0;

  initial begin
    $swrite(up, "HELLO");
    if (up[0] != "H" || up[1] != "E" || up[4] != "O") begin
      $display("FAILED: up = %p", up);
      errors += 1;
    end

    // A descending range still starts at the left bound, and the tail is
    // zero filled, exactly as the string literal assignment does.
    $swrite(down, "HEL", "LO");
    if (down != ref_down || down[6] != "H" || down[2] != "O" || down[1] != 0
        || down[0] != 0) begin
      $display("FAILED: down = %p", down);
      errors += 1;
    end

    // Too long: the first characters are kept.
    $sformat(tiny, "%0d-%s", 12, "xyz");
    if (tiny[0] != "1" || tiny[1] != "2" || tiny[2] != "-") begin
      $display("FAILED: tiny = %p", tiny);
      errors += 1;
    end

    // A shorter string overwrites the whole array.
    $swriteh(up, 8'hab);
    if (up[0] != "a" || up[1] != "b" || up[2] != 0 || up[4] != 0) begin
      $display("FAILED: up(hex) = %p", up);
      errors += 1;
    end

    if (errors == 0) $display("PASSED");
  end
endmodule
