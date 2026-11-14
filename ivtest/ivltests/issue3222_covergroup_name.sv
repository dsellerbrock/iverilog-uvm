module issue3222_covergroup_name;
  int v;
  covergroup cg(string n, string c);
    option.name = n;
    option.comment = c;
    cp: coverpoint v;
  endgroup
  covergroup expr_cg(string n);
    option.name = {n, "_suffix"};
    cp: coverpoint v;
  endgroup
  cg a, b, empty_name;
  expr_cg e;
  string arg;
  initial begin
    arg = "first";
    a = new(arg, "comment A");
    arg = "second";
    b = new(arg, "comment B");
    empty_name = new("", "empty");
    e = new("expr");
    arg = "changed";
    if (a.option.name != "first" || b.option.name != "second" ||
        a.option.comment != "comment A" || b.option.comment != "comment B" ||
        empty_name.option.name != "" || e.option.name != "expr_suffix")
      $fatal(1, "incorrect constructor option values: %s/%s %s/%s empty=%s expr=%s",
             a.option.name, a.option.comment, b.option.name, b.option.comment,
             empty_name.option.name, e.option.name);
    $display("PASS: constructor covergroup names");
    $finish;
  end
endmodule
