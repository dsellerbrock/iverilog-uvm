module sv_enum_unbased_x;
  typedef enum integer {IDLE=0, XX='x, S1='b01, S2='b10} int_state_t;
  int_state_t state;

  initial begin
    if (XX !== 32'bx)
      $fatal(1, "integer enum 'x did not fill base type: %b", XX);
    if (IDLE !== 0 || S1 !== 1 || S2 !== 2)
      $fatal(1, "defined enum values changed: %b %b %b", IDLE, S1, S2);
    $display("PASSED");
  end
endmodule
