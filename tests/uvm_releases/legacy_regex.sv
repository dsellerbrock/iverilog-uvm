module main;
  import uvm_pkg::*;
  import "DPI-C" context uvm_re_match = function int legacy_match(string re, string str);
  import "DPI-C" context uvm_glob_to_re = function string legacy_glob(string glob);
  initial begin
    uvm_root root;
    uvm_report_server server;
    string converted, saved, limit_glob, expanded, oversized, limit_re;
    int errors_before;
    root=uvm_root::get(); server=uvm_report_server::get_server();
    root.set_report_severity_action(UVM_ERROR,UVM_COUNT);
    errors_before=server.get_severity_count(UVM_ERROR);
    converted=legacy_glob("agent.*"); saved=converted;
    if (converted != "/^agent\\..*$/") $fatal(1,"glob conversion: <%s>",converted);
    if (legacy_match(converted,"agent.child") != 0 ||
        legacy_match(converted,"other.child") == 0) $fatal(1,"glob polarity");
    if (legacy_match("/^abc[0-9]+$/","abc73") != 0 ||
        legacy_match("/^abc[0-9]+$/","abcX") == 0) $fatal(1,"regex polarity");
    if (legacy_match("^$","") != 0 || legacy_match("^$","anything") == 0 || legacy_match("/","/") != 0 ||
        legacy_match("/","abc") == 0) $fatal(1,"empty-string or single slash regex");
    if (legacy_glob("") != "/^$/" || legacy_glob("/") != "/^$/" ||
        legacy_glob("/^abc$/") != "/^abc$/") $fatal(1,"glob delimiters");
    if (legacy_glob("a?+[b](c)") != "/^a..+\\[b\\]\\(c\\)$/") $fatal(1,"glob escapes");
    if (legacy_glob("^a?$") != "/^a.$/") $fatal(1,"glob duplicate anchors");
    limit_re={2048{"a"}};
    if (legacy_match(limit_re,limit_re) != 0) $fatal(1,"regex input boundary");
    limit_glob={2040{"a"}};
    converted=legacy_glob(limit_glob);
    if (converted != {"/^",limit_glob,"$/"}) $fatal(1,"glob input boundary");
    expanded=legacy_glob({2040{"."}});
    if (expanded != {"/^",{2040{"\\."}},"$/"}) $fatal(1,"expanded glob truncated");
    if (saved != "/^agent\\..*$/") $fatal(1,"DPI string lifetime");
    if (legacy_match("*","anything") == 0 || legacy_match("[","x") == 0)
      $fatal(1,"invalid regex accepted or retried as glob");
    oversized={2041{"a"}};
    if (legacy_glob(oversized) != oversized) $fatal(1,"oversize glob return");
    if (legacy_match({2049{"a"}},"x") == 0) $fatal(1,"oversize regex accepted");
    if (server.get_severity_count(UVM_ERROR) != errors_before+4 ||
        server.get_id_count("UVM/DPI/REGEX_INV") != 2 ||
        server.get_id_count("UVM/DPI/REGEX_MAX") != 2)
      $fatal(1,"legacy regex errors did not reach UVM");
    $display("PASSED"); $finish(0);
  end
endmodule
