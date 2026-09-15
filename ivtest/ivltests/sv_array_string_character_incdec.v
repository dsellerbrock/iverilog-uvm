module sv_array_string_character_incdec;
  string values[3:2]; int wc,cc; byte old,newval;
  function automatic int wi(); wc++; return 2; endfunction
  function automatic int ci(); cc++; return 1; endfunction
  task automatic local_update;
    string local_values[-1:0]; byte got;
    local_values[-1]="ABC"; local_values[0]="DEF";
    got=local_values[-1][1]++;
    if(got!=66 || local_values[-1]!="ACC" || local_values[0]!="DEF") $fatal(1,"automatic array");
  endtask
  initial begin
    values[3]="keep"; values[2]="ABC";
    old=values[wi()][ci()]++;
    newval=--values[2][2];
    if(values[3]!="keep" || values[2]!="ACB" || old!=66 || newval!=66 || wc!=1 || cc!=1) $fatal(1,"incdec");
    old=values[2][0]--; newval=++values[2][0];
    if(values[2]!="ACB" || old!=65 || newval!=65) $fatal(1,"four operators");
    local_update(); $display("PASSED");
  end
endmodule
