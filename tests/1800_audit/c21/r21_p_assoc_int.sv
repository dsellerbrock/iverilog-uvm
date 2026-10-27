module m;
int a[int];
initial begin
  a[3]=7; a[9]=8;
  $display("assoc_int [%p]", a);
end
endmodule
