class array_holder;
  logic [15:0] values[0:1];
endclass
module sv_class_array_packed_incdec;
  array_holder first, second, current;
  int word_calls, base_calls;
  function automatic int word_index();
    word_calls++; current=second; return 0;
  endfunction
  function automatic int packed_base();
    base_calls++; first.values[0][15:8]=8'h3c; return 0;
  endfunction
  initial begin
    logic [3:0] result;
    first=new; second=new;
    first.values='{16'ha55a,16'h1234}; second.values='{16'hc3c3,16'h5678};
    current=first; word_calls=0; base_calls=0;
    result=current.values[word_index()][packed_base()+:4]++;
    if (result!==4'ha || first.values[0]!==16'h3c5b || first.values[1]!==16'h1234 ||
        second.values[0]!==16'hc3c3 || current!=second || word_calls!=1 || base_calls!=1)
      $fatal(1,"receiver/word/base capture or current-neighbor RMW");
    $display("PASSED");
  end
endmodule
