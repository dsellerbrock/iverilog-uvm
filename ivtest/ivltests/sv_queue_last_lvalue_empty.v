module test;
  int q[$];
  int bounded[$:1];
  initial begin
    q[$]=12;
    if(q.size()!=0) $fatal(1,"empty last grew queue");
    bounded.push_back(1); bounded.push_back(2); bounded[$]=9;
    if(bounded.size()!=2 || bounded[0]!=1 || bounded[1]!=9) $fatal(1,"bounded last");
    $display("PASSED"); $finish(0);
  end
endmodule
