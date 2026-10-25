module sv_format_s_leading_zeros;
  string result;
  initial begin
    result = $sformatf("%s", 32'h00006162);
    $display("implicit=[%s]", result);
    $display("explicit=[%8s]", 32'h00006162);
    $display("string=[%s]", " ab");
    $finish;
  end
endmodule
