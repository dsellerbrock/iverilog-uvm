module m; int A[2][3][4]; int cnt=0; initial begin foreach (A[i,,k]) cnt+=i; $display("omit cnt=%0d",cnt); end endmodule
