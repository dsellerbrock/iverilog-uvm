module top;
  bit value;

  covergroup cg;
    coverpoint value;
  endgroup

  cg first = new;
  cg second = new;
  string second_default_name;
  string requested_name;

  initial begin
    second_default_name = second.option.name;
    requested_name = "inst_x";
    first.set_inst_name(requested_name);
    if (first.option.name != "inst_x"
        || second.option.name != second_default_name) begin
      $display("FAIL set_inst_name name=%s other=%s", first.option.name,
               second.option.name);
      $fatal(1);
    end

    first.set_inst_name("inst_y");
    if (first.option.name != "inst_y") begin
      $display("FAIL set_inst_name replacement=%s", first.option.name);
      $fatal(1);
    end

    $display("PASS 19.8.set_inst_name");
    $finish;
  end
endmodule
