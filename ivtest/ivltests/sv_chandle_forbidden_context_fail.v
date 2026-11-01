module sv_chandle_forbidden_context_fail;
  chandle ch, a, b;
  int i;

  initial begin
    i = ch + 1;
    @(ch);
  end

  assign a = b;
endmodule
