module test;
  bit [15:0] q[$];
  bit [31:16] nonzero[$];
  bit [0:15] ascending[$];
  int calls;
  function int offset(); calls++; return 4; endfunction
  initial begin
    calls=0;
    q.push_back(16'h1234); q.push_back(0);
    q[$][0]=1;
    q[$][7:4]=4'ha;
    q[$][offset() +: 4]=4'hb;
    q[$][15 -: 4]=4'hc;
    if(q.size()!=2 || q[0]!=16'h1234 || q[1]!=16'hc0b1 || calls!=1) $fatal(1,"last parts");
    nonzero.push_back(0); nonzero[$][20 +: 4]=4'hf;
    if(nonzero[0]!=16'h00f0) $fatal(1,"nonzero range");
    ascending.push_back(0); ascending[$][0]=1; ascending[$][4:7]=4'ha;
    if(ascending[0]!=16'h8a00) $fatal(1,"ascending range");
    $display("PASSED"); $finish(0);
  end
endmodule
