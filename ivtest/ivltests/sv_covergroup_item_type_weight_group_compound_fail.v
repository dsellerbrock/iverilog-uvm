module test;
  localparam int arg=3;
  covergroup cg(int arg) with function sample(bit x);
    type_option.weight=arg+0; cx: coverpoint x;
  endgroup
  cg c;
  initial c=new(2);
endmodule
