module sv_array_string_character_compound;
  string values[3:2];
  int word_calls, char_calls, rhs_calls;
  function automatic int word_once(); word_calls++; return 2; endfunction
  function automatic int char_once(); char_calls++; return 1; endfunction
  function automatic int rhs_once(); rhs_calls++; return 1; endfunction
  task automatic local_update;
    string local_values[-1:0];
    local_values[-1]="ABC"; local_values[0]="DEF";
    local_values[-1][1] += 1;
    if(local_values[-1]!="ACC" || local_values[0]!="DEF") $fatal(1,"automatic array");
  endtask
  initial begin
    values[3]="DEF"; values[2]="ABC";
    values[word_once()][char_once()] += rhs_once();
    if(values[3]!="DEF" || values[2]!="ACC" || word_calls!=1 || char_calls!=1 || rhs_calls!=1)
      $fatal(1,"capture/range failure");
    local_update();
    $display("PASSED");
  end
endmodule
