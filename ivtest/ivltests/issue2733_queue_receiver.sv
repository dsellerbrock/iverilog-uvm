module issue2733_regression;
  class box; logic [31:0] values[$]; int intvals[$]; string names[$]; real reals[$]; endclass
  box boxes[$]; box b; int calls; logic [31:0] x; logic [31:0] r[$];
  function automatic int ri(); calls++; return 0; endfunction
  initial begin
    b=new; b.values={1,2,3,4,5}; b.intvals={7,8}; b.names={"a","z"}; b.reals={1.0,2.5}; boxes={b};
    calls=0; x=boxes[ri()].values[$];
    if (x!==5 || calls!=1) $fatal(1,"last x=%0d calls=%0d",x,calls);
    calls=0; x=boxes[ri()].intvals[$];
    if (x!==8 || calls!=1) $fatal(1,"int last x=%0d calls=%0d",x,calls);
    calls=0; if (boxes[ri()].names[$] != "z" || calls!=1) $fatal(1,"string calls=%0d",calls);
    calls=0; if (boxes[ri()].reals[$] != 2.5 || calls!=1) $fatal(1,"real calls=%0d",calls);
    calls=0; r=boxes[ri()].values[1:$];
    if (r.size()!=4 || r[0]!=2 || r[3]!=5 || calls!=1) $fatal(1,"slice calls=%0d",calls);
    b.values.delete(); calls=0; x=boxes[ri()].values[$];
    if (x!==32'bx || calls!=1) $fatal(1,"empty x=%h calls=%0d",x,calls);
    $display("PASS");
  end
endmodule
