module t;
  initial assert final (0) else void'($display("MUST NOT RUN"));
endmodule
