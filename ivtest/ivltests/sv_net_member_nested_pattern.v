// A nested named assignment pattern onto a struct MEMBER through a
// CONTINUOUS assign (IEEE 1800-2017 10.9.2). The same pattern in an
// always_comb was already accepted, so the two forms disagreed.
//
// The net-side l-value synthesizes a bare vector of the right WIDTH for
// the member slice, and PGAssign::elaborate hands that type to the
// r-value -- so the pattern was matched against a bit count ("Packed
// array assignment pattern expects 10 element(s)") and the nested
// patterns then hit "scalar type is not a valid context". The member
// names had nowhere to bind.
//
// The procedural spelling is elaborated alongside and compared bit for
// bit, so a fix that merely made this compile -- while placing the
// members in the wrong slice -- still fails here.
module sv_net_member_nested_pattern;

  typedef struct packed { logic de; logic [3:0] d; }   fld_t;
  typedef struct packed { fld_t rev; fld_t loc; }      cap_t;
  typedef struct packed { cap_t tpm_cap; logic [7:0] other; } hw2reg_t;

  hw2reg_t hw;   // driven continuously
  hw2reg_t hp;   // driven procedurally, the reference

  int errors = 0;

  assign hw.tpm_cap = '{ rev: '{de:1'b1, d:4'h5}, loc: '{de:1'b0, d:4'hA} };
  assign hw.other   = 8'h3C;

  always_comb begin
    hp.tpm_cap = '{ rev: '{de:1'b1, d:4'h5}, loc: '{de:1'b0, d:4'hA} };
    hp.other   = 8'h3C;
  end

  task ck(input string t, input [17:0] got, input [17:0] exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %h expected %h", t, got, exp);
      errors = errors + 1;
    end
  endtask

  initial begin
    #1;
    // absolute values, member by member
    ck("rev.de", {17'b0, hw.tpm_cap.rev.de}, 18'd1);
    ck("rev.d",  {14'b0, hw.tpm_cap.rev.d},  18'h5);
    ck("loc.de", {17'b0, hw.tpm_cap.loc.de}, 18'd0);
    ck("loc.d",  {14'b0, hw.tpm_cap.loc.d},  18'hA);
    // the untouched sibling member must not have been disturbed
    ck("other",  {10'b0, hw.other},          18'h3C);
    // and the whole thing must equal the procedural spelling
    ck("whole",  {8'b0, hw.tpm_cap},         {8'b0, hp.tpm_cap});
    ck("all",    hw,                         hp);

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
  end

endmodule
