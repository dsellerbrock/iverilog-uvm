module test;
 logic [1:0][7:0] words;
 bit [1:0][7:0] two_state;
 integer pos; logic [1:0][7:0] memory [0:1]; integer word_index;
 initial begin
 words=16'ha520;two_state=16'ha520;pos=-2;
 words[1][pos+:4] +=4'd1;
 two_state[1][pos+:4] +=4'd1;
 $display("four=%b two=%h",words,two_state);
 if(words[1][7:2]!==6'b101001 || words[1][1:0]!==2'bxx || words[0]!==8'h20)$fatal(1,"four-state bounded read wrong");
 if(two_state!==16'ha520)$fatal(1,"two-state bounded read wrong");
 words=16'ha520; words[0][6+:4] ^= 4'hf; if(words!==16'ha5e0)$fatal(1,"constant high %h",words);
 words=16'ha520; words[1][-2+:4] ^= 4'hf; if(words!==16'ha620)$fatal(1,"constant low %h",words);
 memory[0]=16'ha520; memory[1]=16'hb530; word_index=1;
 memory[0][0][6+:4] ^= 4'hf; memory[word_index][1][-2+:4] ^= 4'hf;
 if(memory[0]!==16'ha5e0 || memory[1]!==16'hb630)$fatal(1,"array constants %h %h",memory[0],memory[1]);
 $display("PASSED");end
endmodule
