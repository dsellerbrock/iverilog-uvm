`define MACRO4(VAL) `"""line1\
line2 - VAL\
line3 - backslash\\\
line4`"""

module sv_triple_quoted_macro_continuation;
    initial $display(`MACRO4(FOO));
endmodule
