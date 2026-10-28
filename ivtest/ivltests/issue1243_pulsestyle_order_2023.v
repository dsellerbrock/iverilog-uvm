module bad(input a, output y);
  buf(y,a);
  specify
    (a => y)=1;
    pulsestyle_ondetect y;
  endspecify
endmodule
