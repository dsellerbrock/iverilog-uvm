module sv_const_string_real_format_argument_fail;
 function automatic string illegal(input string arg);string s;s.realtoa(arg);return s;endfunction
 localparam string VALUE=illegal("1.5");
endmodule
