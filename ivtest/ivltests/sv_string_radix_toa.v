module test;
   string str;
   int value;

   initial begin
      value = 32'hffffffff;
      str.hextoa(value);
      if (str != "ffffffff" || str.atohex() != value)
        $fatal(1, "hextoa(-1)=%s", str);
      str.octtoa(value);
      if (str != "37777777777" || str.atooct() != value)
        $fatal(1, "octtoa(-1)=%s", str);
      str.bintoa(value);
      if (str != "11111111111111111111111111111111" || str.atobin() != value)
        $fatal(1, "bintoa(-1)=%s", str);

      value = 32'h80000000;
      str.hextoa(value);
      if (str != "80000000" || str.atohex() != value)
        $fatal(1, "hextoa(0x80000000)=%s", str);
      str.octtoa(value);
      if (str != "20000000000" || str.atooct() != value)
        $fatal(1, "octtoa(0x80000000)=%s", str);
      str.bintoa(value);
      if (str != "10000000000000000000000000000000" || str.atobin() != value)
        $fatal(1, "bintoa(0x80000000)=%s", str);

      value = 32'hdeadbeef;
      str.hextoa(value);
      if (str != "deadbeef" || str.atohex() != value)
        $fatal(1, "hextoa(0xdeadbeef)=%s", str);

      str.itoa(32'h80000000);
      if (str != "-2147483648")
        $fatal(1, "itoa(0x80000000)=%s", str);
      $display("PASS");
      $finish;
   end
endmodule
