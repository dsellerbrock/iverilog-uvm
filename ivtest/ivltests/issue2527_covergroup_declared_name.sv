covergroup issue2527_cg;
  option.name = "named";
  coverpoint 1;
endgroup

module issue2527_covergroup_declared_name;
  issue2527_cg cg = new();
  initial begin
    if (cg.option.name != "named")
      $fatal(1, "declared covergroup name was ignored: %s", cg.option.name);
    $display("PASS: declared covergroup name is preserved");
    $finish;
  end
endmodule
