module sv_const_string_format_argument_fail;
 function automatic string illegal(input string arg);string s;s.itoa(arg);return s;endfunction
 localparam string VALUE=illegal("abc");
endmodule
