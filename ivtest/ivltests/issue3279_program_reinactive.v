// Issue #3279: IEEE 1800-2023 4.5. The reference algorithm runs the
// Reactive..Post-Re-NBA loop to completion before control returns to the
// Active region set, so a program's #0 (Re-Inactive) resumes before the
// design process its write woke (Active).
program prog;
  initial begin
    #1 tb.a = 1;
    #0 $display("%0t prog after #0 b=%0d", $time, tb.b);
  end
endprogram
module tb;
  int a = 0, b = 0;
  prog p();
  always @(a) begin b = a; $display("%0t design ran", $time); end
endmodule
