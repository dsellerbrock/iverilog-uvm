module r06_19f_enum_name_len_chain;
  typedef enum {red, green, blue} Colors;
  Colors c;
  initial begin c = green; $display("INFO name_len_chain=%0d", c.name().len()); end
endmodule
