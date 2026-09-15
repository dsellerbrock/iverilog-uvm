module test;
  covergroup cg(int lo,int hi) with function sample(int value);
    cp: coverpoint value { bins path[] = ([lo:hi] => 0); }
  endgroup
  cg c;
  initial begin c=new(4,1); #0; $fatal(1,"empty transition program accepted"); end
endmodule
