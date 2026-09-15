module test;
  logic [1:0][2:0][7:0] mem[2];
  integer wi, oi, mi, bi;
  integer wc, oc, mc, bc, rc;
  function automatic integer word_index; wc++; return wi; endfunction
  function automatic integer outer; oc++; return oi; endfunction
  function automatic integer middle; mc++; return mi; endfunction
  function automatic integer bit_index; bc++; return bi; endfunction
  function automatic logic [7:0] rhs8; rc++; return 8'h3c; endfunction
  function automatic logic [3:0] rhs4; rc++; return 4'h3; endfunction
  function automatic logic rhs1; rc++; return 1'b0; endfunction
  task automatic reset_counts; wc=0; oc=0; mc=0; bc=0; rc=0; endtask
  task automatic counts(input integer want_bc);
    if (wc!==1 || oc!==1 || mc!==1 || bc!==want_bc || rc!==1)
      $fatal(1,"counts %0d/%0d/%0d/%0d/%0d",wc,oc,mc,bc,rc);
  endtask
  initial begin
    wi=1; oi=1; mi=2; bi=6;
    mem[0]=48'ha5a5a5a5a5a5; mem[1]=48'ha5a5a5a5a5a5;
    reset_counts(); mem[word_index()][outer()][middle()][bit_index()+:4] = rhs4();
    if (mem[1]!==48'he5a5a5a5a5a5) $fatal(1,"blocking %h",mem[1]); counts(1);
    mem[1]=48'ha5a5a5a5a5a5;
    reset_counts(); mem[word_index()][outer()][middle()][bit_index()+:4] ^= rhs4();
    if (mem[1]!==48'h65a5a5a5a5a5) $fatal(1,"compound %h",mem[1]); counts(1);
    mem[1]=48'ha5a5a5a5a5a5;
    reset_counts(); mem[word_index()][outer()][middle()] <= rhs8(); #1;
    if (mem[1]!==48'h3ca5a5a5a5a5) $fatal(1,"whole NBA %h",mem[1]); counts(0);
    mem[1]='0;
    mem[1][0][0][7:4] = 4'hf;
    if (mem[1]!==48'h0000000000f0) $fatal(1,"constant range %h",mem[1]);
    oi=1; mi=2; bi=0; mem[0]=48'ha5a5a5a5a5a5;
    reset_counts(); mem[3][outer()][middle()][bit_index()+:4] ^= rhs4();
    if (mem[0]!==48'ha5a5a5a5a5a5 || oc!==1 || mc!==1 || bc!==1 || rc!==1 || wc!==0)
      $fatal(1,"constant invalid word %h counts %0d/%0d/%0d/%0d/%0d",
             mem[0],wc,oc,mc,bc,rc);
    mi=3; mem[1]=48'ha5a5a5a5a5a5;
    reset_counts(); mem[word_index()][outer()][middle()][bit_index()] <= rhs1(); #1;
    if (mem[1]!==48'ha5a5a5a5a5a5) $fatal(1,"invalid prefix wrote %h",mem[1]); counts(1);
    $display("PASSED");
  end
endmodule
