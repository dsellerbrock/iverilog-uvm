module test;
reg [1:0][2:0][7:0] words;integer oi,mi;
initial begin
words=0;oi=0;mi=0;words[oi][mi+:2]=16'h1234;
if(words!==48'h000000001234)$fatal(1,"valid nonleaf %h",words);
words=0;oi=0;mi=2;words[oi][mi+:2]=16'h1234;
if(words!==48'h000000340000)$fatal(1,"partial nonleaf %h",words);
words=0;oi=2;mi=0;words[oi][mi+:2]=16'h1234;
if(words!==0)$fatal(1,"invalid prefix %h",words);
$display("PASSED");end endmodule
