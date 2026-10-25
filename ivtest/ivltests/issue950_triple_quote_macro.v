`define MACRO4(VAL) `"""line1\
line2 - VAL\
line3 - backslash\\\
line4`"""

module issue950_triple_quote_macro;
    initial $display(`MACRO4(FOO));
endmodule
