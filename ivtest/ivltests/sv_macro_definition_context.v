// IEEE 1800-2017 22.5.1 macro replacement token-context coverage.
`define ADD_ONE(x) ((x) + 1)
`define NESTED(x) `ADD_ONE(`ADD_ONE(x))
`define PASTE(a, b) a``b
`define MESSAGE(x) `"value=x; escaped=`\`"ok`\`"`"
`define PLAIN_STRING(x) "x"
`define URL_STRING "https://example.invalid/a/*not-a-comment*/"
`define SUM(a, b) ((a) + \
                   (b))

module test;
  localparam int pasted_value = 42;
  string url;
  string message;
  string plain;

  initial begin
    url = `URL_STRING;
    message = `MESSAGE(done);
    plain = `PLAIN_STRING(changed);

    if ((2 * `ADD_ONE(2)) !== 6) begin
      $display("FAILED -- parenthesized replacement context");
      $finish;
    end
    if (`NESTED(39) !== 41) begin
      $display("FAILED -- nested replacement expansion");
      $finish;
    end
    if (`PASTE(pasted_, value) !== 42) begin
      $display("FAILED -- token paste boundary");
      $finish;
    end
    if (`SUM(20, 22) !== 42) begin
      $display("FAILED -- continued replacement text");
      $finish;
    end
    if (url != "https://example.invalid/a/*not-a-comment*/") begin
      $display("FAILED -- comment marker in string: %s", url);
      $finish;
    end
    if (message != "value=done; escaped=\"ok\"") begin
      $display("FAILED -- macro quote or escaped quote: %s", message);
      $finish;
    end
    if (plain != "x") begin
      $display("FAILED -- ordinary string substituted a formal: %s", plain);
      $finish;
    end

    $display("PASSED");
  end
endmodule
