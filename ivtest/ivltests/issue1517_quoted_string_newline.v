module quoted_multiline;
  string s = "first
second";
  initial $display("LEN=%0d VALUE=%s", s.len(), s);
endmodule
