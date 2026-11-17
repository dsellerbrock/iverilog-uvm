module main;
  bit a = 0, b = 0, d = 0;
  bit from_default, from_explicit, from_inferred, delayed;
  int count = 0;
  default clocking cb @(posedge b); endclocking

  always @(posedge a) begin
    from_default = $past(d);
    #1;
  end
  always @(posedge a) begin
    from_explicit = $past(d, 1, , @(posedge a));
    #1;
  end
  always @(posedge a) begin
    from_inferred = $past(d);
    delayed <= #1 d;
  end

  initial begin
    #2 b = 1;
    #2 b = 0;
    #1 d = 1;
    #1 a = 1;
    #1 a = 0;
    #1 d = 0;
    #1 b = 1;
    #1 b = 0;
    #1 d = 1;
    #1 a = 1;
    #2;
    if (from_default !== 0 || from_explicit !== 1 || from_inferred !== 1 || delayed !== 1)
      $display("FAILED default=%b explicit=%b inferred=%b delayed=%b", from_default, from_explicit, from_inferred, delayed);
    else
      $display("PASSED");
    $finish;
  end
endmodule
