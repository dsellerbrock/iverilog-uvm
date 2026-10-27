module r06_19d_enum_name_member;
  typedef enum {red, green, blue} Colors;
  Colors c;
  initial begin c = green; $display("INFO name_member=%s", c.name); end
endmodule
