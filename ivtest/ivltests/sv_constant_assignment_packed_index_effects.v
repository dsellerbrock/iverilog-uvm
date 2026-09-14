module test;
 function automatic logic[31:0] calc;
 integer oi,mi,bi,rv;logic[1:0][2:0][7:0] words;
 oi=0;mi=3;bi=0;rv=1;words='0;
 words[oi++][mi++][bi++ +:4]=rv++;
 if(words!==48'h0)return 32'hbad;
 return {oi[7:0],mi[7:0],bi[7:0],rv[7:0]};
 endfunction
 localparam logic[31:0] result=calc();
 initial begin if(result!==32'h01040102)$fatal(1,"constant index effects=%h",result);
 $display("PASSED constant invalid-prefix index effects");end
endmodule
