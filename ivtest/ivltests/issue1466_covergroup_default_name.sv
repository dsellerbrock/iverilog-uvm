covergroup issue1466_cg;
  coverpoint 1;
endgroup

module issue1466_covergroup_default_name;
  issue1466_cg first = new();
  issue1466_cg second = new();

  initial begin
    if (first.option.name == "" || second.option.name == "")
      $fatal(1, "default covergroup name is empty");
    if (first.option.name == second.option.name)
      $fatal(1, "default covergroup names are not unique");
    $display("PASS: default covergroup names are nonempty and unique");
    $finish;
  end
endmodule
