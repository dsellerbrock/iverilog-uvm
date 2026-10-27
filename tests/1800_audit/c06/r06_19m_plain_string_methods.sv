module r06_19m_plain_string_methods;
  string s = "green";
  initial begin
    $display("INFO plain_len=%0d", s.len());
    $display("INFO plain_upper=%s", s.toupper());
    $display("INFO plain_len_bare=%0d", s.len);
  end
endmodule
