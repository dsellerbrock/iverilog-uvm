module sv_assert_multiclock_assoc_internal_read;
  logic c1 = 0, c2 = 0, a = 1, b = 1, good = 1;
  always #1 c1 = ~c1;
  initial begin #100; c2 = 1; #1; c2 = 0; end

  assert property (@(posedge c1) a ##[1:3] b |-> @(posedge c2) good);

  initial begin
    #120;
    $display("PASSED");
    $finish(0);
  end
endmodule
