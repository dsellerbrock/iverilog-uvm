module test_proc_members;
  bit a;
  covergroup cg;
    cp: coverpoint a;
  endgroup
  cg cov = new;
  initial begin
    cov.cp.option.goal = 80;
    cov.cp.option.comment = "audit_comment";
    if (cov.cp.option.goal != 80 || cov.cp.option.comment != "audit_comment")
      $fatal(1, "procedural goal/comment writes did not persist");
    $display("PASS 19.10 procedural goal and comment writes");
    $finish;
  end
endmodule
