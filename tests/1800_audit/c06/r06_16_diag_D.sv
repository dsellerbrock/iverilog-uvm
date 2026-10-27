module t; string n;
  initial begin
    n.hextoa(255); $display("D hex255='%s'", n);
    n.hextoa(32'h7fffffff); $display("D hex7fffffff='%s'", n);
    n.hextoa(-1); $display("D hex-1='%s'", n);
    n.hextoa(32'h80000000); $display("D hex80000000='%s'", n);
    n.octtoa(-1); $display("D oct-1='%s'", n);
    n.octtoa(32'o20000000000); $display("D oct2e9='%s'", n);
    n.bintoa(-1); $display("D bin-1='%s'", n);
    n.bintoa(32'h80000000); $display("D bin80000000='%s'", n);
    n.itoa(32'h80000000); $display("D itoa80000000='%s'", n);
  end
endmodule
