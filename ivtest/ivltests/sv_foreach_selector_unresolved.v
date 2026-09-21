module main;
  int a[2][3];
  initial foreach (a[missing_selector()][j]) ;
endmodule
