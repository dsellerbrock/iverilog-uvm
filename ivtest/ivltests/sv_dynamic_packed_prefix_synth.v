module dut(input logic clk,reset,input logic signed [31:0] oi,mi,bi,input logic down,output logic [1:0][2:0][7:0] words);
always @(posedge clk) if(reset) words<=48'ha5a5a5a5a5a5; else if(down) words[oi][mi][bi-:4]<=4'h3; else words[oi][mi][bi+:4]<=4'h3;
endmodule
module test;
reg clk=0,reset=0,down=0;reg signed[31:0] oi=0,mi=0,bi=0;wire[47:0] words;integer failures=0;
dut d(clk,reset,oi,mi,bi,down,words);
initial begin
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=0;bi=-2;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a4) begin $display("FAIL synth case2 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=0;bi=0;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a3) begin $display("FAIL synth case5 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=0;bi=6;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5e5) begin $display("FAIL synth case8 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=0;bi=11;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case11 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=0;bi=1;down=1;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a4) begin $display("FAIL synth case14 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=0;bi=32'bx;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case17 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=1;mi=2;bi=-2;down=0;#1;clk=1;#1;
if(words!==48'ha4a5a5a5a5a5) begin $display("FAIL synth case20 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=1;mi=2;bi=0;down=0;#1;clk=1;#1;
if(words!==48'ha3a5a5a5a5a5) begin $display("FAIL synth case23 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=1;mi=2;bi=6;down=0;#1;clk=1;#1;
if(words!==48'he5a5a5a5a5a5) begin $display("FAIL synth case26 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=1;mi=2;bi=11;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case29 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=1;mi=2;bi=1;down=1;#1;clk=1;#1;
if(words!==48'ha4a5a5a5a5a5) begin $display("FAIL synth case32 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=1;mi=2;bi=32'bx;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case35 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=2;mi=0;bi=-2;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case38 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=2;mi=0;bi=0;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case41 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=2;mi=0;bi=6;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case44 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=2;mi=0;bi=11;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case47 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=2;mi=0;bi=1;down=1;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case50 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=2;mi=0;bi=32'bx;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case53 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=-1;bi=-2;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case56 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=-1;bi=0;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case59 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=-1;bi=6;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case62 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=-1;bi=11;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case65 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=-1;bi=1;down=1;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case68 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=-1;bi=32'bx;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case71 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=32'bx;mi=0;bi=-2;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case74 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=32'bx;mi=0;bi=0;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case77 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=32'bx;mi=0;bi=6;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case80 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=32'bx;mi=0;bi=11;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case83 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=32'bx;mi=0;bi=1;down=1;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case86 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=32'bx;mi=0;bi=32'bx;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case89 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=32'bz;bi=-2;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case92 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=32'bz;bi=0;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case95 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=32'bz;bi=6;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case98 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=32'bz;bi=11;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case101 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=32'bz;bi=1;down=1;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case104 got=%h",words);failures++;end
clk=0;
reset=1;clk=0;#1;clk=1;#1;clk=0;reset=0;
oi=0;mi=32'bz;bi=32'bx;down=0;#1;clk=1;#1;
if(words!==48'ha5a5a5a5a5a5) begin $display("FAIL synth case107 got=%h",words);failures++;end
clk=0;
if(failures) $fatal(1,"failures=%0d",failures);
$display("PASSED");
end
endmodule
