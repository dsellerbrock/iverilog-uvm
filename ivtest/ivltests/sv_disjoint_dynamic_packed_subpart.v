module test;
  logic [1:0][7:0] words;
  logic [7:0] upper;
  integer pos, base_calls, rhs_calls;
  function automatic integer next_base; base_calls++; return pos; endfunction
  function automatic logic [3:0] next_rhs; rhs_calls++; return 4'h3; endfunction
  assign words[1] = upper;
  initial begin
    upper=8'ha5; words[0]=8'h20; pos=0; base_calls=0; rhs_calls=0;
    words[0][next_base()+:4]=next_rhs(); #1;
    if(words!==16'ha523 || base_calls!=1 || rhs_calls!=1) $fatal(1,"blocking %h",words);
    upper=8'hc7; #1; if(words!==16'hc723) $fatal(1,"continuous update %h",words);
    pos=6; words[0][next_base()+:4]^=4'hf;
    if(words!==16'hc7e3 || base_calls!=2) $fatal(1,"compound %h",words);
    words[0]=8'h20; pos=-2; words[0][next_base()+:4]=4'hf;
    if(words!==16'hc723 || base_calls!=3) $fatal(1,"low partial %h",words);
    words[0]=8'h20; pos=1; words[0][next_base()-:4]=4'hf;
    if(words!==16'hc723 || base_calls!=4) $fatal(1,"descending partial %h",words);
    pos=8; words[0][next_base()+:4]=next_rhs();
    pos='x; words[0][next_base()+:4]=next_rhs();
    if(words!==16'hc723 || base_calls!=6 || rhs_calls!=3) $fatal(1,"invalid base %h",words);
    words[0]=8'h20; pos=0;
    words[0][next_base()+:4] <= #2 next_rhs();
    pos=7; upper=8'ha5; #3;
    if(words!==16'ha523 || base_calls!=7 || rhs_calls!=4) $fatal(1,"NBA capture %h",words);
    $display("PASSED");
  end
endmodule
