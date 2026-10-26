module issue1226_declaration_after_statement;
  initial begin
    int first;
    first = 1;
    int later;
  end
endmodule
