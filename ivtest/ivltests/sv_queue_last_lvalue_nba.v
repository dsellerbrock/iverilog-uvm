module test;
  int q[$];
  bit [15:0] parts[$];
  initial begin
    q.push_back(1); q.push_back(2);
    q[$]<=7;
    q.push_back(3);
    parts.push_back(0); parts[$][7:4]<=4'ha; parts.push_back(16'hffff);
    #1;
    if(q.size()!=3 || q[0]!=1 || q[1]!=7 || q[2]!=3) $fatal(1,"NBA last capture");
    if(parts.size()!=2 || parts[0]!=16'h00a0 || parts[1]!=16'hffff) $fatal(1,"NBA partial last capture");
    $display("PASSED"); $finish(0);
  end
endmodule
