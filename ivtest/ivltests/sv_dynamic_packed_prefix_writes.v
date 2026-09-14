module test;
logic [1:0][2:0][7:0] words;
integer outer_index=0, middle_index, base_index;
integer outer_calls, middle_calls, base_calls, rhs_calls, failures=0;
function automatic integer outer(); outer_calls++; return outer_index; endfunction
function automatic integer middle(); middle_calls++; return middle_index; endfunction
function automatic integer base(); base_calls++; return base_index; endfunction
function automatic logic [3:0] rhs(); rhs_calls++; return 4'hf; endfunction
task reset; words='0; outer_calls=0; middle_calls=0; base_calls=0; rhs_calls=0; endtask
task check(input logic [47:0] expected,input string name);
 if(words!==expected || outer_calls!==1 || middle_calls!==1 || base_calls!==1 || rhs_calls!==1) begin
  $display("FAILED %s got=%h expected=%h calls=%0d/%0d/%0d/%0d",name,words,expected,outer_calls,middle_calls,base_calls,rhs_calls); failures++;
 end
endtask
initial begin
 middle_index=3; base_index=0;
 reset(); words[outer()][middle()][base()+:4]=rhs(); check(0,"invalid prefix blocking");
 reset(); words[outer()][middle()][base()+:4]^=rhs(); check(0,"invalid prefix compound");
 reset(); words[outer()][middle()][base()+:4]<=rhs(); #1; check(0,"invalid prefix NBA");
 middle_index=1; base_index=6;
 reset(); words[outer()][middle()][base()+:4]=rhs(); check(48'hc000,"tail spill blocking");
 reset(); words[outer()][middle()][base()+:4]^=rhs(); check(48'hc000,"tail spill compound");
 reset(); words[outer()][middle()][base()+:4]<=rhs(); #1; check(48'hc000,"tail spill NBA");
 if(failures) $fatal(1,"failures=%0d",failures);
 $display("PASSED");
end
endmodule
