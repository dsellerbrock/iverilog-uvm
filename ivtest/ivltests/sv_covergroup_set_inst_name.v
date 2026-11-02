module top;
  bit value;
  covergroup cg;
    coverpoint value;
  endgroup

  cg first = new;
  cg second = new;
  string assigned_name;

  function cg get_first();
    return first;
  endfunction

  initial begin
    assigned_name = "inst_x";
    first.set_inst_name(assigned_name);
    second.set_inst_name("inst_y");

    if (first.option.name != "inst_x" || second.option.name != "inst_y")
      $fatal(1, "set_inst_name did not set each instance name");

    get_first().set_inst_name("renamed");
    if (first.option.name != "renamed" || second.option.name != "inst_y")
      $fatal(1, "set_inst_name did not update only its receiver");

    $display("PASS covergroup set_inst_name");
  end
endmodule
