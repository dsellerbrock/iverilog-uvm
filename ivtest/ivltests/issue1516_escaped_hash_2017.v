module issue1516_escaped_hash;
  logic \# ;
  initial begin
    \# = 1'b1;
    $display("hash=%b", \# );
  end
endmodule
