class C;
  function string get(); return path; endfunction
  string path = "member";
endclass
module top;
  C c;
  initial begin c = new; if (c.get() != "member") $fatal(1); $display("PASSED"); end
endmodule
