// `assert final` remains a deliberate compile-error guard until reports
// mature in the Postponed region of every time step.
module test();

integer i = 1;

initial begin
  assert final (i == 1);
  assert final (i == 0);
  assert final (i == 1) else $display("Check 3 : this shouldn't be displayed");
  assert final (i == 0) else $display("Check 4 : this should be displayed");
  assert final (i == 1) $display("Check 5 : this should be displayed");
  assert final (i == 0) $display("Check 6 : this shouldn't be displayed");
  assert final (i == 1) $display("Check 7 : this should be displayed");
    else $display("Check 7 : this shouldn't be displayed");
  assert final (i == 0) $display("Check 8 : this shouldn't be displayed");
    else $display("Check 8 : this should be displayed");
end

endmodule
