// IEEE1800-2017 12.5.3: unique/unique0 case statements must warn at
// runtime if MORE THAN ONE case item matches the selector. priority
// case must NOT warn on the same overlap (first-match-wins is its
// defined behavior). This test exercises: unique (overlap), unique0
// (overlap), priority (overlap, silent), casez (overlapping wildcard
// patterns), a loop that fires the check N times, and a control case
// with no overlaps that must stay completely silent.

module main;
   reg [1:0] sel;
   integer   i;

   initial begin
      // 1) unique case with two overlapping items (both match sel==1).
      //    Expect: ONE multiple-match warning, and the FIRST matching
      //    branch (item 0) executes.
      sel = 2'd1;
      unique case (sel)
        2'd1: $display("U overlap: first branch");
        2'd1: $display("U overlap: second branch (should not print)");
        2'd2: $display("U overlap: third branch (should not print)");
      endcase

      // 2) unique0 case, same overlap shape.
      sel = 2'd1;
      unique0 case (sel)
        2'd1: $display("U0 overlap: first branch");
        2'd1: $display("U0 overlap: second branch (should not print)");
        2'd2: $display("U0 overlap: third branch (should not print)");
      endcase

      // 3) priority case, same overlap shape: must NOT warn, and must
      //    still take the first matching branch.
      sel = 2'd1;
      priority case (sel)
        2'd1: $display("P overlap: first branch");
        2'd1: $display("P overlap: second branch (should not print)");
        2'd2: $display("P overlap: third branch (should not print)");
      endcase

      // 4) casez with overlapping wildcard patterns: sel==2'b11
      //    matches both 2'b1? and 2'b?1.
      sel = 2'b11;
      unique casez (sel)
        2'b1?: $display("Uz overlap: first branch");
        2'b?1: $display("Uz overlap: second branch (should not print)");
      endcase

      // 5) loop executing a unique case with an overlap N times: one
      //    warning is expected PER execution (N total).
      for (i = 0; i < 3; i = i + 1) begin
         unique case (2'd0)
           2'd0: $display("loop %0d: first branch", i);
           2'd0: $display("loop %0d: second branch (should not print)", i);
         endcase
      end

      // 6) control: unique case with NO overlaps must stay silent
      //    (no multiple-match warning).
      sel = 2'd2;
      unique case (sel)
        2'd0: $display("control: item 0 (should not print)");
        2'd2: $display("control: item 2");
        2'd3: $display("control: item 3 (should not print)");
      endcase

      $display("PASSED");
   end
endmodule
