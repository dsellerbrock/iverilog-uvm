module issue2575_oob_2state_array;
  bit [7:0] bits_array[0:3];
  logic [7:0] logic_array[0:3];
  logic [31:0] index;

  initial begin
    foreach (bits_array[i]) begin
      bits_array[i] = 8'h11;
      logic_array[i] = 8'h22;
    end

    index = 7;
    $display("bit const oob: %h", bits_array[7]);
    $display("logic const oob: %h", logic_array[7]);
    $display("bit var oob: %h", bits_array[index]);
    $display("logic var oob: %h", logic_array[index]);
    if (bits_array[7] !== 8'h00) $fatal(1, "constant bit OOB read");
    if (logic_array[7] !== 8'hxx) $fatal(1, "constant logic OOB read");
    if (bits_array[index] !== 8'h00) $fatal(1, "variable bit OOB read");
    if (logic_array[index] !== 8'hxx) $fatal(1, "variable logic OOB read");

    index = 32'hx;
    $display("bit x-index: %h", bits_array[index]);
    $display("logic x-index: %h", logic_array[index]);
    if (bits_array[index] !== 8'h00) $fatal(1, "unknown bit index read");
    if (logic_array[index] !== 8'hxx) $fatal(1, "unknown logic index read");
    $display("PASSED");
  end
endmodule
