`pragma protect author="begin_protected"
`pragma protect author="escaped \" begin_protected, still a string"
`pragma protect author_info="prefix begin_protected suffix", author="begin_protected"
`pragma protect author="text" // begin_protected
module issue3096_protect_author;
  initial begin
    $display("PASS");
  end
endmodule
