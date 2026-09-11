// Original UVM 1.0p1/1.1a ABI, without loading or modifying a UVM package.
module main;
  import "DPI-C" function string dpi_get_next_arg_c();
  import "DPI-C" function string dpi_get_tool_name_c();
  import "DPI-C" function string dpi_get_tool_version_c();
  import "DPI-C" function chandle dpi_regcomp(string pattern);
  import "DPI-C" function int dpi_regexec(chandle expression, string text);
  import "DPI-C" function void dpi_regfree(chandle expression);
  import "DPI-C" function string uvm_dpi_get_tool_name_c();
  import "DPI-C" function string uvm_dpi_get_tool_version_c();
  import "DPI-C" function int uvm_dpi_regexec(chandle expression, string text);
  import "DPI-C" function void uvm_dpi_regfree(chandle expression);

  initial begin
    string args[$];
    string arg;
    chandle first, second;
    arg = dpi_get_next_arg_c();
    while (arg != "") begin
      args.push_back(arg);
      if (args.size() > 32) $fatal(1, "argument iterator did not terminate");
      arg = dpi_get_next_arg_c();
    end
    // The runner supplies these four literal arguments after the program name.
    if (args.size() != 5 || args[0] == "" ||
        args[1] != "+legacy_dpi=alpha" || args[2] != "-f" ||
        args[3] != "literal.txt" || args[4] != "+legacy_dpi=beta")
      $fatal(1, "actual runtime argv lost, reordered or reinterpreted");
    repeat (2) begin
      foreach (args[i]) begin
        arg = dpi_get_next_arg_c();
        if (arg != args[i]) $fatal(1, "argument iteration did not restart");
      end
      if (dpi_get_next_arg_c() != "") $fatal(1, "missing end marker");
    end
    if (dpi_get_tool_name_c() != "Icarus Verilog" ||
        dpi_get_tool_name_c() != uvm_dpi_get_tool_name_c() ||
        dpi_get_tool_version_c() == "" ||
        dpi_get_tool_version_c() != uvm_dpi_get_tool_version_c())
      $fatal(1, "tool metadata mismatch");

    first = dpi_regcomp("^item[0-9]+$");
    second = dpi_regcomp("^other$");
    if (first == null || second == null ||
        dpi_regexec(first, "item42") != 0 ||
        dpi_regexec(first, "itemX") == 0 ||
        uvm_dpi_regexec(first, "prefix_item42") == 0)
      $fatal(1, "strict legacy regex semantics");
    uvm_dpi_regfree(first);
    if (dpi_regexec(second, "other") != 0)
      $fatal(1, "independent regex lifetime");
    dpi_regfree(second);
    if (dpi_regexec(null, "anything") == 0) $fatal(1, "null handle matched");
    dpi_regfree(null);
    first = dpi_regcomp("*[");
    if (first != null) $fatal(1, "invalid ERE accepted");
    dpi_regfree(first);
    $display("PASSED");
    $finish(0);
  end
endmodule
