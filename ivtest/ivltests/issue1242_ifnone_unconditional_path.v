module issue1242_ifnone_unconditional_path(input a, output y);
  assign y=a;
  specify
    if (a) (a => y)=1;
    ifnone (a => y)=2;
    (a => y)=3;
  endspecify
endmodule
