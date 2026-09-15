module sv_array_string_character_store_bounds;
  string values[2];
  logic unknown;
  logic [127:0] wide, word_high, char_mixed, char_high, char_x;
  int word_calls, character_calls, rhs_calls;
  function automatic logic [127:0] word_once(input logic [127:0] value); word_calls++; return value; endfunction
  function automatic logic [127:0] character_once(input logic [127:0] value); character_calls++; return value; endfunction
  function automatic byte rhs_once(input byte value); rhs_calls++; return value; endfunction
  initial begin
    values[0]="ABC"; values[1]="DEF";
    unknown=1'bx; wide={128{1'b1}};
    word_high='0; word_high[64]=1'b1;
    char_mixed='0; char_mixed[1:0]=2'b1x;
    char_high='0; char_high[100]=1'b1;
    char_x='x;
    values[word_once(unknown)][character_once(1)] = rhs_once("Z");
    if (values[0]!="ABC" || values[1]!="DEF") $fatal(1,"X word stored");
    values[word_once(wide)][character_once(1)] = rhs_once("Z");
    values[word_once(1)][character_once(wide)] = rhs_once("Z");
    values[word_once(1)][character_once(1)] = rhs_once(0);
    values[word_once(word_high)][character_once(1)] = rhs_once("Z");
    if (values[0]!="ABC" || values[1]!="DEF"
        || word_calls!=5 || character_calls!=5 || rhs_calls!=5)
      $fatal(1,"invalid/zero boundary or call count");
    values[0][character_once(char_mixed)] = rhs_once("Z");
    values[0][character_once(char_high)] = rhs_once("Y");
    values[0][character_once(char_x)] = rhs_once("X");
    values[1] = "";
    values[1][character_once(0)] = rhs_once("Z");
    values[0][character_once(99)] = rhs_once("Q");
    values[0][character_once(1)] = rhs_once(8'bxxxxxxxx);
    values[0][character_once(1)] = rhs_once(8'bzzzzzzzz);
    if (values[0]!="XBZ" || values[1]!=""
        || word_calls!=5 || character_calls!=12 || rhs_calls!=12)
      $fatal(1,"character int/byte boundaries or call count");
    $display("PASSED");
  end
endmodule
