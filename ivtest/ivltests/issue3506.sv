// IEEE 1800-2017/2023 12.6: a constant expression pattern is integral and
// has the type of the value it is matched against. The string literal
// "exact" is the 40-bit integral constant 40'h6578616374 (5.9), so it
// matches an equal logic [39:0] payload of the same tag.
module issue3506;
  typedef union tagged { void None; logic [39:0] Text; } u_t;
  u_t a;
  int hits;

  task automatic check(input u_t v, input int want);
    int got;
    got = 0;
    case (v) matches
      tagged Text "exact": got = 1;
      default: got = 2;
    endcase
    if (got !== want) begin
      $display("FAILED: case matches got %0d, want %0d", got, want);
      $finish;
    end
  endtask

  initial begin
    check(tagged Text 40'h6578616374, 1);
    check(tagged Text 40'h6578616375, 2);
    check(tagged None, 2);

    a = tagged Text "exact";
    if (a matches tagged Text "exact") hits++;
    else $display("FAILED: if matches");
    if ((a matches tagged Text "exact" ? 1 : 0) !== 1)
      $display("FAILED: conditional matches");
    else hits++;
    casez (a) matches
      tagged Text "exact": hits++;
      default: $display("FAILED: casez matches");
    endcase
    a = tagged None;
    if (a matches tagged Text "exact") $display("FAILED: inactive tag matched");
    else hits++;

    if (hits === 4) $display("PASSED");
  end
endmodule
