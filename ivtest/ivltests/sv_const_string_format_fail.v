module sv_const_string_format_fail;
 string external_text;
 function automatic string illegal(input integer value);
  external_text.itoa(value);
  return external_text;
 endfunction
 localparam string VALUE=illegal(7);
endmodule
