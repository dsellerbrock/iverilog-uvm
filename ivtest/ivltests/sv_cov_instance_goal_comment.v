covergroup cov_t with function sample(int a, int b);
  cp_a: coverpoint a;
  cp_b: coverpoint b;
  cr_ab: cross cp_a, cp_b;
endgroup
module sv_cov_instance_goal_comment;
  cov_t cg = new;
  initial begin
    cg.option.goal = 11;
    cg.option.comment = "group updated";
    cg.cp_a.option.goal = 12;
    cg.cp_a.option.comment = "point updated";
    cg.cr_ab.option.goal = 13;
    cg.cr_ab.option.comment = "cross updated";
    if (cg.option.goal != 11 || cg.option.comment != "group updated" ||
        cg.cp_a.option.goal != 12 || cg.cp_a.option.comment != "point updated" ||
        cg.cr_ab.option.goal != 13 || cg.cr_ab.option.comment != "cross updated")
      $fatal(1, "coverage option readback mismatch");
    cg.sample(0, 1);
    $display("PASS: procedural coverage goal/comment options");
    $finish;
  end
endmodule
