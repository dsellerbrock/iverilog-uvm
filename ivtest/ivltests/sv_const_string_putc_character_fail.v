module sv_const_string_putc_character_fail;
 function automatic string illegal(input string character);string s="ABC";s.putc(1,character);return s;endfunction
 localparam string VALUE=illegal("Z");
endmodule
