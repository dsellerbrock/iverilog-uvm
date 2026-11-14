typedef bit [15:0] word_t;
typedef logic [15:0] logic_word_t;
module issue3027_assoc_packed;
  bit [7:0] signed_keys[int];
  logic [7:0] string_keys[string];
  logic_word_t four;
  word_t two;
  initial begin
    signed_keys[4] = 8'h12;
    signed_keys[-1] = 8'h34;
    two = word_t'(signed_keys);
    if (two !== 16'h3412) $fatal(1, "signed order: %h", two);
    string_keys["z"] = 8'b01xz1010;
    string_keys["a"] = 8'hc3;
    four = logic_word_t'(string_keys);
    if (four !== 16'b11000011_01xz1010) $fatal(1, "string order: %b", four);
    two = word_t'(string_keys);
    if (two !== 16'b11000011_01001010) $fatal(1, "two-state conversion: %b", two);
    $display("PASS");
  end
endmodule
