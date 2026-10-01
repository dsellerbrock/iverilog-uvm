// An output/inout actual of a function call that is a bit or part select of
// a vector variable receives the formal's value, truncated to the selected
// width (IEEE 1800-2017/2023 13.5, 11.5.1). The copy-out was skipped with a
// warning when the select was narrower than the formal, so the variable never
// changed (OpenTitan chip uvm_hdl_read(path, cur_val[i])).
typedef logic [31:0] data_t;

class reader;
  function bit rd(string p, output data_t value);
    value = (p == "a") ? 32'h0000_00a5 : 32'hffff_ff00;
    return 1;
  endfunction
  function bit bump(inout data_t value);
    value = value + 1;
    return 1;
  endfunction
endclass

module main;
  int errors;
  reader r = new;

  task automatic check(string what, logic [15:0] got, logic [15:0] want);
    if (got !== want) begin
      $display("FAILED %s: got %b want %b", what, got, want);
      errors++;
    end
  endtask

  initial begin
    bit [3:0] cur_val;
    logic [7:0] bytes;
    bit [15:0] wide;
    string io[4];
    int j;
    io = '{"a", "b", "a", "b"};

    cur_val = 4'b0000;
    foreach (cur_val[i]) void'(r.rd(io[i], cur_val[i]));
    check("bit select per index", cur_val, 4'b0101);

    bytes = 8'h00;
    void'(r.rd("a", bytes[7:4]));
    check("part select upper nibble", bytes, 8'h50);
    void'(r.rd("b", bytes[3:0]));
    check("part select lower nibble", bytes, 8'h50);

    wide = 16'h0000;
    void'(r.rd("a", wide[15:8]));
    check("part select byte", wide, 16'ha500);

    bytes = 8'hff;
    j = 2;
    void'(r.rd("a", bytes[j]));
    check("variable bit, formal low bit 1", bytes, 8'hff);
    void'(r.rd("b", bytes[j]));
    check("variable bit, formal low bit 0", bytes, 8'hfb);

    bytes = 8'h0f;
    j = 9;
    void'(r.rd("a", bytes[j]));
    check("out of range select leaves variable", bytes, 8'h0f);

    cur_val = 4'b0000;
    void'(r.bump(cur_val[2]));
    check("inout bit select", cur_val, 4'b0100);

    if (errors == 0) $display("PASSED");
  end
endmodule
