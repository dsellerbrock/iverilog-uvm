module sv_array_string_character_incdec_bounds;
  string values[2]; logic[127:0] wh,cm,ch,cx,wx; int wc,cc; int wide_result; byte result;
  function automatic logic[127:0] w(input logic[127:0]v);wc++;return v;endfunction
  function automatic logic[127:0] c(input logic[127:0]v);cc++;return v;endfunction
  initial begin
    values[0]="\310\377"; values[1]="";
    wh='0;wh[64]=1;cm='0;cm[1:0]=2'b1x;ch='0;ch[100]=1;cx='x;wx='x;
    result=values[w(wh)][c(0)]++;
    if(result!=0 || values[0]!="\310\377") $fatal(1,"invalid word");
    result=values[w(0)][c(cm)]++;
    if(result!=0 || values[0]!="\310\377") $fatal(1,"OOB char");
    result=++values[w(0)][c(-1)];
    if(result!=1 || values[0]!="\310\377") $fatal(1,"negative char");
    result=values[w(wx)][c(0)]++;
    if(result!=0 || values[0]!="\310\377") $fatal(1,"unknown word");
    wide_result=values[w(0)][c(ch)]++;
    if(wide_result!=-56 || values[0]!="\311\377") $fatal(1,"signed postfix");
    wide_result=++values[w(0)][c(cx)];
    if(wide_result!=-54 || values[0]!="\312\377") $fatal(1,"signed prefix");
    wide_result=++values[w(0)][c(1)];
    if(wide_result!=0 || values[0]!="\312\377") $fatal(1,"zero suppression");
    result=++values[w(1)][c(0)];
    if(result!=1 || values[1]!="" || wc!=8 || cc!=8) $fatal(1,"empty/calls");
    $display("PASSED");
  end
endmodule
