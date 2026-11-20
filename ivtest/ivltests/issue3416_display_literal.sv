module issue3416_display_literal;
  localparam string typed_text = "var %0d|%h";
  localparam packed_text = "ABCDE";
  localparam signed packed_signed = "A";
  string fs = "var %0d|%h";
  logic [7:0] x = 8'd200;
  logic [24:0] cast_bits = 25'h250068;
  string written;

  function automatic string write_result(input string data, input logic [7:0] n);
    $swrite(write_result, data, n, "|%0h", n, "|end");
  endfunction

  function automatic string write_hex_result(input string data, input logic [7:0] n);
    $swriteh(write_hex_result, data, n);
  endfunction

  initial begin
    $display(fs, x, x);
    $display("var %0d|%h", x, x);
    $display(typed_text, x, x);
    $display(string'("cast %0d"), x);
    $display("constant=<", string'(24'h250068), x, ">");
    $display("dynamic=<", string'(cast_bits), x, ">");
    $display({fs, "%%"}, x);
    $display("packed=<", packed_text, ">");
    $displayh("concat=<", {"AB", "CDE"}, ">");
    $displayh("conditional=<", 1'b1 ? "A" : "B", ">");
    $display("signed=<", packed_signed, ">");
    $display("empty=<", , ">");
    $display("first=%0d", x, " second=%s", fs, " third=%s", "%%");
    $fdisplay(1, fs, x, " hex=%0h", x);

    $swrite(written, fs, x, "|%0h", x, "|end");
    $display("swrite=<%s>", written);
    $display("return=<%s>", write_result(fs, x));
    $display("return hex=<%s>", write_hex_result(fs, x));
    $sformat(written, fs, x, x);
    $display("sformat=<%s>", written);
    $display("sformatf=<%s>", $sformatf(fs, x, x));

    $fstrobe(1, "strobe=", fs, x);
    fs = "changed %%";
    #1 $monitor("monitor=", fs, x);
    #1 fs = "next %0d";
    #1 $monitoroff;
  end
endmodule
