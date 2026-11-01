module sv_constraint_mixed_signed_unsigned;
  class c_t;
    rand bit [7:0] w;
    rand bit signed [7:0] sv;
    constraint k { sv inside {[-20:19]}; w == sv + 100; }
  endclass

  c_t c = new;
  int bad;
  initial begin
    repeat (40) begin
      if (!c.randomize()) $fatal(1, "randomize unexpectedly failed");
      if (!(c.w == c.sv + 100)) bad++;
    end
    if (bad != 0)
      $fatal(1, "mixed signed/unsigned constraint violation: bad=%0d", bad);
    $display("PASS mixed signed/unsigned constraint context");
    $display("PASSED");
  end
endmodule
