module m; int cnt=0, sum=0, n=0, off=1, s=0; logic xc=1'bx; logic [3:0] xr=4'bx; logic [7:0] tmp=8'hB6; int q[$]='{3,4,5}; int aa[string]; string kk;
initial begin forever begin cnt++; if (cnt==3) break; end $display("forever cnt=%0d sum=%0d s=%0d", cnt, sum, s); end endmodule
