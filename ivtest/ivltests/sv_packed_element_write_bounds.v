module test;
  logic [1:0][7:0] words;
  logic [1:0][0:7] ascending;
  logic [3:4][7:0] nonzero_prefix;
  logic [-1:-2][7:0] negative_prefix;
  integer pos;
  longint unsigned wide;
  logic [1:0][7:0] memory [0:1];
  integer word_index, word_calls, base_calls;
  integer rhs_calls;

  function automatic integer next_word; word_calls++; return word_index; endfunction
  function automatic integer next_base; base_calls++; return pos; endfunction
  function automatic logic [3:0] next_rhs; rhs_calls++; return 4'hf; endfunction

  function automatic logic [1:0][7:0] make_value(input integer base);
    make_value = 16'ha520;
    make_value[0][base +: 4] = 4'hf;
  endfunction

  function automatic logic [1:0][7:0] make_compound(input integer base);
    make_compound = 16'ha520;
    make_compound[0][base +: 4] ^= 4'hf;
  endfunction

  task automatic check(input logic [15:0] expected, input string label);
    if (words !== expected) $fatal(1, "FAILED %s: %h", label, words);
  endtask

  initial begin
    words=16'ha520; pos=6; words[0][pos+:4]=4'hf; check(16'ha5e0,"upper +:");
    words=16'ha520; pos=-2; words[1][pos+:4]=4'hf; check(16'ha720,"lower +:");
    words=16'ha520; pos=9; words[0][pos-:4]=4'hf; check(16'ha5e0,"upper -:");
    words=16'ha520; pos=8; words[0][pos+:4]=4'hf; check(16'ha520,"outside");
    words=16'ha520; pos='x; words[0][pos+:4]=4'hf; check(16'ha520,"X base");
    words=16'ha520; pos='z; words[0][pos+:4]=4'hf; check(16'ha520,"Z base");
    words=16'ha520; wide=64'hffff_ffff_ffff_ffff; words[0][wide+:4]=4'hf; check(16'ha520,"wide base");
    words=16'ha520; words[0][6+:4]=4'hf; check(16'ha5e0,"constant base");
    if (make_value(6)!==16'ha5e0) $fatal(1,"FAILED function return");
    if (make_compound(6)!==16'ha5e0) $fatal(1,"FAILED compound function return");
    memory[0]=16'ha520; memory[1]=16'hb530; word_index=0; pos=6; word_calls=0; base_calls=0;
    memory[next_word()][0][next_base()+:4]=4'hf;
    if (memory[0]!==16'ha5e0 || memory[1]!==16'hb530 || word_calls!=1 || base_calls!=1)
      $fatal(1,"FAILED array blocking: %h %h calls %0d %0d",memory[0],memory[1],word_calls,base_calls);
    ascending=16'ha53c; ascending[0][5+:4]=4'hf;
    if (ascending!==16'ha53f) $fatal(1,"FAILED ascending: %h",ascending);

    words=16'ha520; pos=0; base_calls=0; rhs_calls=0;
    words[2][next_base()+:4]=next_rhs();
    if(words!==16'ha520 || base_calls!=1 || rhs_calls!=1) $fatal(1,"FAILED OOB prefix blocking");
    words[2][next_base()+:4]^=next_rhs();
    if(words!==16'ha520 || base_calls!=2 || rhs_calls!=2) $fatal(1,"FAILED OOB prefix compound");
    words[2][next_base()+:4]<=next_rhs(); #1;
    if(words!==16'ha520 || base_calls!=3 || rhs_calls!=3) $fatal(1,"FAILED OOB prefix NBA");
    words[1'bx][next_base()+:4]=next_rhs();
    words[1'bz][next_base()+:4]=next_rhs();
    words[64'h1_0000_0000][next_base()+:4]=next_rhs();
    if(words!==16'ha520 || base_calls!=6 || rhs_calls!=6) $fatal(1,"FAILED invalid prefix values");

    memory[0]=16'ha520; memory[1]=16'hb530; word_index=0;
    word_calls=0; base_calls=0; rhs_calls=0;
    memory[next_word()][2][next_base()+:4]=next_rhs();
    memory[next_word()][2][next_base()+:4]^=next_rhs();
    memory[next_word()][2][next_base()+:4]<=next_rhs(); #1;
    if(memory[0]!==16'ha520 || memory[1]!==16'hb530)
      $fatal(1,"FAILED unpacked invalid prefix");
    if(word_calls!=3 || base_calls!=3 || rhs_calls!=3)
      $fatal(1,"FAILED unpacked side effects %0d %0d %0d",word_calls,base_calls,rhs_calls);
    nonzero_prefix=16'ha520; nonzero_prefix[3][6+:4]=4'hf;
    if(nonzero_prefix!==16'he520) $fatal(1,"FAILED nonzero valid prefix %h",nonzero_prefix);
    nonzero_prefix[2][next_base()+:4]=next_rhs();
    if(nonzero_prefix!==16'he520) $fatal(1,"FAILED nonzero invalid prefix");
    negative_prefix=16'ha520; negative_prefix[-1][6+:4]=4'hf;
    if(negative_prefix!==16'he520) $fatal(1,"FAILED negative valid prefix");
    $display("PASSED");
  end
endmodule
