module issue3739;
  logic signed [65:0] base;
  logic [7:0] source, blocking_value, nba_value;

  task automatic check(input logic signed [65:0] index,
                       input logic [3:0] expected_read,
                       input logic [7:0] expected_store);
    logic [3:0] selected;
    base = index;
    selected = source[base +: 4];
    if (selected !== expected_read)
      $fatal(1, "base %h: read %b, expected %b", base, selected, expected_read);

    blocking_value = source;
    nba_value = source;
    blocking_value[base +: 4] = 4'hf;
    nba_value[base +: 4] <= 4'hf;
    #1;
    if (blocking_value !== expected_store || nba_value !== expected_store)
      $fatal(1, "base %h: blocking %h, NBA %h, expected %h",
             base, blocking_value, nba_value, expected_store);
  endtask

  initial begin
    source = 8'ha5;
    check(-66'sh1_0000_0000_0000_0000, 4'bxxxx, 8'ha5);
    check(-66'sh1_0000_0000_0000_0001, 4'bxxxx, 8'ha5);
    check( 66'sh1_0000_0000_0000_0000, 4'bxxxx, 8'ha5);
    check({2'b0x, 64'b0}, 4'bxxxx, 8'ha5);
    check({2'b0z, 64'b0}, 4'bxxxx, 8'ha5);
    check(-66'sd1, 4'b101x, 8'ha7);
    check( 66'sd1, 4'b0010, 8'hbf);
    $display("PASSED");
  end
endmodule
