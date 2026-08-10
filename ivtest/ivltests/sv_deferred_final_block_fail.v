module t;
  initial assert final (0) else begin
    $display("MUST NOT RUN");
  end
endmodule
