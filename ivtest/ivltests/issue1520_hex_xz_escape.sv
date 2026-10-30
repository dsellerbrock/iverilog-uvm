module issue1520_hex_xz_escape;
  string upper_x = "\xX1";
  string lower_x = "\xx1";
  string upper_z = "\xZ1";
  string lower_z = "\xz1";
  initial $display("%s", upper_x);
endmodule
