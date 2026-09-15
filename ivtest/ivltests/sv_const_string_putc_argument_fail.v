module sv_const_string_putc_argument_fail;
 function automatic string illegal(input string index);string s="ABC";s.putc(index,"Z");return s;endfunction
 localparam string VALUE=illegal("1");
endmodule
