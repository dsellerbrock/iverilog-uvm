module sv_const_string_putc_fail;
 string external_text="ABC";
 function automatic string illegal();external_text.putc(1,"Z");return external_text;endfunction
 localparam string VALUE=illegal();
endmodule
