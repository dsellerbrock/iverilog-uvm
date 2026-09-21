module test;
  import uvm_pkg::*;
  import "DPI-C" function chandle uvm_re_comp(input string re, input bit deglob);
  import "DPI-C" function int uvm_re_exec(input chandle compiled, input string value);
  import "DPI-C" function void uvm_re_free(input chandle compiled);
  import "DPI-C" context uvm_re_match = function int legacy_match(string re, string value);
  chandle strict, glob, valid, slash;
  initial begin
    uvm_root root;
    uvm_report_server server;
    int saved_action, errors_before, invalid_before;
    strict = uvm_re_comp("*[", 0);
    if (strict != null) $fatal(1, "strict glob accepted");
    glob = uvm_re_comp("*_shadowed", 1);
    valid = uvm_re_comp(".*_shadowed", 0);
    slash = uvm_re_comp("/.*_shadowed/", 0);
    if (glob == null || valid == null || slash == null) $fatal(1, "legal expression rejected");
    if (uvm_re_exec(glob, "alert_shadowed") != 0 ||
        uvm_re_exec(valid, "alert_shadowed") != 0 ||
        uvm_re_exec(slash, "alert_shadowed") != 0) $fatal(1, "positive match failed");
    if (uvm_re_exec(valid, "alert_regwen") == 0) $fatal(1, "negative match accepted");
    uvm_re_free(glob); uvm_re_free(valid); uvm_re_free(slash);
    glob = uvm_re_comp("*[", 1);
    if (glob == null || uvm_re_exec(glob, "x[") != 0 || uvm_re_exec(glob, "x") == 0)
      $fatal(1, "explicit conversion of invalid strict pattern failed");
    uvm_re_free(glob);
    valid = uvm_re_comp({2048{"a"}}, 0);
    strict = uvm_re_comp({2049{"a"}}, 0);
    if (valid == null || strict != null) $fatal(1, "regex length boundary");
    uvm_re_free(valid);
    if (legacy_match("/^a[0-9]+$/", "a123") != 0 ||
        legacy_match("/^a[0-9]+$/", "abc") == 0)
      $fatal(1, "legacy strict semantics changed");
    // Count the expected error without hiding errors from any other report ID.
    root = uvm_root::get();
    server = uvm_report_server::get_server();
    errors_before = server.get_severity_count(UVM_ERROR);
    invalid_before = server.get_id_count("UVM/DPI/REGEX_INV");
    saved_action = root.get_report_action(UVM_ERROR, "UVM/DPI/REGEX_INV");
    root.set_report_severity_id_action(UVM_ERROR, "UVM/DPI/REGEX_INV", UVM_COUNT);
    if (legacy_match("*[", "x[") == 0) $fatal(1, "legacy invalid regex accepted");
    root.set_report_severity_id_action(UVM_ERROR, "UVM/DPI/REGEX_INV", saved_action);
    if (server.get_severity_count(UVM_ERROR) != errors_before + 1 ||
        server.get_id_count("UVM/DPI/REGEX_INV") != invalid_before + 1)
      $fatal(1, "legacy invalid-regex diagnostic missing or duplicated");
    $display("PASSED");
  end
endmodule
