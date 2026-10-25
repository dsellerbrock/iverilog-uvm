module p06_16d;
  int pass=0, fail=0;
  task automatic ck(input string id, input bit c); if (c) pass++; else begin fail++; $display("FAIL %s", id); end endtask
  string n;  real rv;
  initial begin
    n = "123";   ck("atoi", n.atoi() == 123);
    n = "1_2x3"; ck("atoi_us", n.atoi() == 12);
    n = "abc";   ck("atoi_none", n.atoi() == 0);
    n = "";      ck("atoi_empty", n.atoi() == 0);
    n = "ff";    ck("atohex", n.atohex() == 255);
    n = "FF_ff"; ck("atohex_us", n.atohex() == 65535);
    n = "12abz"; ck("atohex_stop", n.atohex() == 16'h12ab);
    n = "1_7";   ck("atooct", n.atooct() == 15);
    n = "789";   ck("atooct_stop", n.atooct() == 7);
    n = "1_0_1"; ck("atobin", n.atobin() == 5);
    n = "102";   ck("atobin_stop", n.atobin() == 2);
    n = "3.5";   ck("atoreal", n.atoreal() == 3.5);
    n = "1.5e2x"; ck("atoreal_exp", n.atoreal() == 150.0);
    n = "abc";   ck("atoreal_none", n.atoreal() == 0.0);
    n = "-5";    $display("INFO atoi(-5)=%0d", n.atoi());
    n = "0x1f";  $display("INFO atohex(0x1f)=%0d", n.atohex());
    n = "12345678901"; $display("INFO atoi(big)=%0d", n.atoi());
    n = "-1.25"; rv = n.atoreal(); $display("INFO atoreal(-1.25)=%f", rv);
    n = "stale"; n.itoa(7); ck("itoa_repl", n == "7" && n.len() == 1);
    n.itoa(-42); ck("itoa_neg", n == "-42");
    n.itoa(0); ck("itoa_0", n == "0");
    n.hextoa(255); ck("hextoa", n.tolower() == "ff");
    n.hextoa(32'hdeadbeef); ck("hex_rt", n.tolower() == "deadbeef" && n.atohex() == 32'hdeadbeef);
    n.octtoa(15); ck("octtoa", n == "17");
    n.bintoa(5); ck("bintoa", n == "101");
    n.bintoa(0); ck("bintoa0", n == "0");
    n.realtoa(2.5); ck("realtoa_rt", n.atoreal() == 2.5); $display("INFO realtoa(2.5)=%s", n);
    n.hextoa(-1); $display("INFO hextoa(-1)=%s", n);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
