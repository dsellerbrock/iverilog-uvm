module test;
 logic[1:0][7:0] memory[0:1]; logic[1:0][7:0] direct; integer word_calls,base_calls;integer word_index,pos;logic[3:0] data;
 function automatic integer wi;word_calls++;return word_index;endfunction
 function automatic integer bi;base_calls++;return pos;endfunction
 initial begin
 direct=16'ha520; direct[0][0+:16] <= 16'hffff;
 memory[0]=16'ha520;memory[1]=16'hb530;word_calls=0;base_calls=0;word_index=0;pos=6;data=4'hf;
 memory[wi()][0][bi()+:4] <= #2 data;
 memory[0][1] <= #2 8'hc7;
 word_index=1;pos=0;data=0;
 #3;
 if(direct!==16'ha5ff)$fatal(1,"zero-base full-width escaped carrier %h",direct);
 if(word_calls!=1||base_calls!=1)$fatal(1,"indices repeated %d %d",word_calls,base_calls);
 if(memory[0]!==16'hc7e0||memory[1]!==16'hb530)$fatal(1,"capture/clipping wrong %h %h",memory[0],memory[1]);
 $display("PASSED");end
endmodule
