module p18r;
 int pass=0, fail=0; task automatic ck(input string id, input bit c); if (c) pass++; else begin fail++; $display("FAIL %s", id); end endtask
 string seq; int nadd=0, ndec=0, depth=0, pushes=0, pops=0, rep=0, sel; int bad=0;
 initial begin
  repeat (500) begin seq = "";
   randsequence (main)
    main   : first second done ;
    first  : add := 3 | dec := (1 + 1) ;
    second : pop | push ;
    done   : { seq = {seq, "D"}; } ;
    add    : { seq = {seq, "a"}; nadd++; } ;
    dec    : { seq = {seq, "d"}; ndec++; } ;
    pop    : { seq = {seq, "p"}; } ;
    push   : { seq = {seq, "u"}; } ;
   endsequence
   if (!(seq inside {"apD","auD","dpD","duD"})) bad++;
  end
  $display("INFO add %0d dec %0d of 500", nadd, ndec);
  ck("outcomes", bad == 0); ck("weights_3_2", nadd >= 255 && nadd <= 345 && nadd + ndec == 500);
  depth = 0;
  repeat (6) randsequence () PP_OP : if (depth < 2) PUSH else POP ; PUSH : { ++depth; pushes++; } ; POP : { --depth; pops++; } ; endsequence
  ck("if_else", pushes == 4 && pops == 2 && depth == 2);
  sel = 0; randsequence () SELECT : case (2 & 7) 0 : NETWORK ; 1, 2 : DISK ; default : MEMORY ; endcase ; NETWORK : { sel = 1; } ; DISK : { sel = 2; } ; MEMORY : { sel = 3; } ; endsequence
  ck("case", sel == 2);
  randsequence () TOP : repeat (3) ONE ; ONE : { rep++; } ; endsequence
  ck("repeat", rep == 3);
  $display("RESULT pass=%0d fail=%0d", pass, fail); if (fail != 0) $fatal(1, "randsequence probe failed");
 end
endmodule
