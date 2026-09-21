// IEEE 1800-2017/2023 16.13: grouping preserves clock flow.
module probe #(parameter OVERLAP=0, COINCIDENT=0, CANCEL=0, BAD=0)
 (output reg done=0);
  reg c1=0,c2=0,good=1,reset=0;
  integer gp=0,gf=0,up=0,uf=0;
  generate if (OVERLAP) begin
    assert property (@(posedge c1) disable iff(reset)
      1 |-> (((@(posedge c2) good)))) gp++; else gf++;
    assert property (@(posedge c1) disable iff(reset)
      1 |-> @(posedge c2) good) up++; else uf++;
  end else begin
    assert property (@(posedge c1) disable iff(reset)
      1 |=> (((@(posedge c2) good)))) gp++; else gf++;
    assert property (@(posedge c1) disable iff(reset)
      1 |=> @(posedge c2) good) up++; else uf++;
  end endgenerate
  initial begin
    if (COINCIDENT) good=0;
    #10;
    c1=1;
    if (COINCIDENT) c2=1;
    #2; c1=0;c2=0;
    #3; if(CANCEL) reset=1;
    good=!BAD;
    #5; c2=1;
    #2;
    if (gp!=up || gf!=uf) $fatal(1,"grouped/control mismatch");
    if (CANCEL) begin
      if(gp!=0 || gf!=0) $fatal(1,"disabled obligation survived");
    end else if ((OVERLAP && COINCIDENT) || BAD) begin
      if(gp!=0 || gf!=1) $fatal(1,"expected one failure: p=%0d f=%0d",gp,gf);
    end else begin
      if(gp!=1 || gf!=0) $fatal(1,"expected one success: p=%0d f=%0d",gp,gf);
    end
    done=1;
  end
endmodule
module tail_probe(output reg done=0);
  reg c1=0,c2=0,c3=0,good=1,bad=0;
  integer gp=0,gf=0,up=0,uf=0;
  assert property (@(posedge c1)
    1 |=> (@(posedge c2) good ##1 @(posedge c3) bad)) gp++; else gf++;
  assert property (@(posedge c1)
    1 |=> @(posedge c2) good ##1 @(posedge c3) bad) up++; else uf++;
  initial begin
    #10; c1=1; #10; c2=1; #10; c3=1; #2;
    if(gp!=0 || gf!=1 || up!=0 || uf!=1)
      $fatal(1,"grouping lost later clock transition");
    done=1;
  end
endmodule
module test;
  wire [6:0] done;
  probe #(0,0,0,0) distinct_n(done[0]);
  probe #(1,0,0,0) distinct_o(done[1]);
  probe #(0,1,0,0) coincident_n(done[2]);
  probe #(1,1,0,0) coincident_o(done[3]);
  probe #(0,0,1,0) cancelled(done[4]);
  probe #(0,0,0,1) bad(done[5]);
  tail_probe tail(done[6]);
  initial begin
    #35;
    if(done!==7'b1111111) $fatal(1,"missing verdict");
    $display("PASSED"); $finish(0);
  end
endmodule
