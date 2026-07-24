module top;
  int a[2][3]; string r;
  initial begin foreach(a[i,j]) a[i][j]=i*3+j; r=$sformatf("%p",a);
    if (r=="'{'{0, 1, 2}, '{3, 4, 5}}") $display("PASS"); else $display("FAIL got %0s",r); $finish(0); end
endmodule
