module main;
  int a[2][3];
  int i;
  initial begin
    for (i=0; i<2; i++) a[i] = '{default:7};
    if (a[0][0] != 7 || a[1][2] != 7) $fatal(1,"variable row assignment lost values");
    i=0; a[i] <= a[1]; i=1;
    #1;
    if (a[0][2] != 7) $fatal(1,"NBA row assignment lost values");
    $display("PASSED");
  end
endmodule
