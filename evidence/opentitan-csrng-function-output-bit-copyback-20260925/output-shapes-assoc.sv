// IEEE 1800-2017/2023 6.11.2 and 13.5: output copy-out converts X/Z to
// zero for a two-state actual after width adjustment. Four-state actuals
// retain X/Z, and a native task follows the same conversion rule.
class bit_holder;
  bit [31:0] value;
  bit [31:0] entries[string];
endclass

module sv_function_output_bit_copyback;
  bit [31:0] direct;
  bit [31:0] words[2];
  bit [3:0] narrow;
  bit_holder holder;
  logic [31:0] four;
  int result;

  function automatic int read_wide(output logic [1023:0] data);
    data = '1;
    data[31:8] = 'x;
    data[7:4] = 4'ha;
    data[3:0] = 4'bx1z0;
    return 7;
  endfunction

  task automatic read_task(output logic [31:0] data);
    data = 'x;
    data[7:4] = 4'ha;
    data[3:0] = 4'bx1z0;
  endtask

  initial begin
    holder = new;

    result = read_wide(direct);
    if (result != 7 || direct !== 32'ha4 || $isunknown(direct))
      $display( "direct bit output copyback: result=%0d data=%h", result, direct);

    result = read_wide(narrow);
    if (result != 7 || narrow !== 4'h4 || $isunknown(narrow))
      $display( "narrow bit output copyback: result=%0d data=%h", result, narrow);

    result = read_wide(words[1]);
    if (result != 7 || words[1] !== 32'ha4 || words[0] !== 32'h0)
      $display( "array bit output copyback: data=%h neighbor=%h", words[1], words[0]);

    result = read_wide(holder.value);
    if (result != 7 || holder.value !== 32'ha4 || $isunknown(holder.value))
      $display( "property bit output copyback: data=%h", holder.value);

    result = read_wide(holder.entries["k"]);
    $display("assoc entry=%h unknown=%0d", holder.entries["k"], $isunknown(holder.entries["k"]));

    result = read_wide(four);
    if (result != 7 || four[31:8] !== {24{1'bx}}
        || four[7:4] !== 4'ha || four[3:0] !== 4'bx1z0)
      $display( "four-state output copyback: data=%h", four);

    read_task(direct);
    if (direct !== 32'ha4 || $isunknown(direct))
      $display( "task bit output copyback: data=%h", direct);

    $display("DIAGNOSTIC DONE");
  end
endmodule
