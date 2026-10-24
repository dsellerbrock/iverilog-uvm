module r06_19e_enum_name_call;
  typedef enum {red, green, blue} Colors;
  Colors c;
  initial begin c = green; $display("INFO name_call=%s", c.name()); end
endmodule
