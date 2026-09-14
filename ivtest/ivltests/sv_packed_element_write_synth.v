module dut(input logic[3:0] data, input integer pos, output logic[1:0][7:0] words, output bit[1:0][7:0] two_state);
 always @* begin words=16'ha520;two_state=16'ha520;words[1][pos+:4]+=data;two_state[1][pos+:4]+=data;end
endmodule
module test;
 logic[3:0] data;integer pos;wire[15:0] words,two_state;
 dut d(data,pos,words,two_state);
 initial begin data=1;pos=-2;#1;
 if(words[15:10]!==6'b101001 || words[9:8]!==2'bxx || words[7:0]!==8'h20)$fatal(1,"four-state oldvalue %b",words);
 if(two_state!==16'ha520)$fatal(1,"two-state oldvalue %h",two_state);
 $display("PASSED");end
endmodule
