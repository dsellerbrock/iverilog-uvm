module issue1466_covergroup_option_name;
  covergroup cg;
    cp: coverpoint 1;
  endgroup

  cg first = new;
  cg second = new;

  initial begin
    if (first.option.name == "" || second.option.name == "")
      $fatal(1, "default covergroup instance name is empty");
    if (first.option.name == second.option.name)
      $fatal(1, "default covergroup instance names are not unique");
    $display("PASS");
    $finish;
  end
endmodule
