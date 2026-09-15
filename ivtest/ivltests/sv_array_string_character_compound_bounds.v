module sv_array_string_character_compound_bounds;
  string values[2];
  logic [127:0] word_high, char_mixed, char_high, all_x;
  int wc,cc,rc;
  function automatic logic[127:0] w(input logic[127:0]v); wc++; return v; endfunction
  function automatic logic[127:0] c(input logic[127:0]v); cc++; return v; endfunction
  function automatic int r(); rc++; return 1; endfunction
  initial begin
    values[0]="ABC"; values[1]="";
    word_high='0; word_high[64]=1; char_mixed='0; char_mixed[1:0]=2'b1x; char_high='0; char_high[100]=1; all_x='x;
    values[w(word_high)][c(1)] += r();
    values[w(0)][c(char_mixed)] += r();
    values[w(0)][c(char_high)] += r();
    values[w(1)][c(0)] += r();
    values[w(0)][c(99)] += r();
    values[w(0)][c(all_x)] -= r();
    if(values[0]!="ABD" || values[1]!="" || wc!=6 || cc!=6 || rc!=6)
      $fatal(1,"bounds v=%s calls=%0d/%0d/%0d",values[0],wc,cc,rc);
    $display("PASSED");
  end
endmodule
