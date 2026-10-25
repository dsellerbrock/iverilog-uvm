// IEEE 1800-2017/2023 19.7 and 19.10: procedural access to instance options.
module test;
  covergroup cg with function sample(int x, int y);
    a: coverpoint x;
    b: coverpoint y;
    ab: cross a, b;
  endgroup

  initial begin
    cg c;
    c = new;
    if (c.option.goal != 100 || c.option.comment != "" ||
        c.a.option.goal != 100 || c.a.option.comment != "" ||
        c.ab.option.goal != 100 || c.ab.option.comment != "")
      $fatal(1, "coverage option defaults are incorrect");

    c.option.goal = 55;
    c.option.comment = "group comment";
    c.a.option.goal = 45;
    c.a.option.comment = "point comment";
    c.ab.option.goal = 35;
    c.ab.option.comment = "cross comment";

    if (c.option.goal != 55 || c.option.comment != "group comment" ||
        c.a.option.goal != 45 || c.a.option.comment != "point comment" ||
        c.ab.option.goal != 35 || c.ab.option.comment != "cross comment")
      $fatal(1, "procedural coverage options did not retain values");
    $display("PASSED");
    $finish(0);
  end
endmodule
