// IEEE 1800-2017/2023 13.5: copy an output formal into a packed word of
// one fixed-array class property slot without changing adjacent storage.
module sv_function_copyout_packed_property_select;
  class Item;
    bit [7:0][31:0] key[2];
  endclass
  Item obj, saved_obj;
  bit [7:0][31:0] keep0, keep1;
  int slot_calls, word_calls;
  int slot_value;
  logic [3:0] word_value;

  function automatic int slot();
    slot_calls++;
    return slot_value;
  endfunction
  function automatic logic [3:0] word();
    word_calls++;
    return word_value;
  endfunction
  function automatic int hdl_read(output logic [1023:0] value);
    value = '0;
    value[64] = 1'b1;
    value[31:0] = 32'hdeadcafe;
    value[4] = 1'bx;
    return 1;
  endfunction

  initial begin
    obj = new;
    obj.key[0][1] = 32'h11223344;
    obj.key[1][0] = 32'h55667788;
    slot_value = 0;
    word_value = 0;
    if (!hdl_read(obj.key[slot()][word()])) $fatal(1, "return");
    if (obj.key[0][0] !== 32'hdeadcaee
        || obj.key[0][1] !== 32'h11223344
        || obj.key[1][0] !== 32'h55667788) $fatal(1, "copy-out");
    if (slot_calls != 1 || word_calls != 1)
      $fatal(1, "address evaluation");
    slot_value = 1;
    word_value = 3;
    if (!hdl_read(obj.key[slot()][word()])) $fatal(1, "nonzero offset return");
    if (obj.key[1][3] !== 32'hdeadcaee
        || obj.key[1][0] !== 32'h55667788) $fatal(1, "nonzero offset");
    keep0 = obj.key[0];
    keep1 = obj.key[1];
    slot_value = 2;
    if (!hdl_read(obj.key[slot()][0])) $fatal(1, "invalid slot return");
    if (obj.key[0] !== keep0 || obj.key[1] !== keep1)
      $fatal(1, "invalid slot alias");
    slot_value = 0;
    word_value = 'x;
    if (!hdl_read(obj.key[0][word()])) $fatal(1, "X offset return");
    if (obj.key[0] !== keep0 || obj.key[1] !== keep1)
      $fatal(1, "X offset alias");
    word_value = 8;
    if (!hdl_read(obj.key[0][word()])) $fatal(1, "OOB offset return");
    if (obj.key[0] !== keep0 || obj.key[1] !== keep1)
      $fatal(1, "OOB offset alias");
    saved_obj = obj;
    obj = null;
    if (!hdl_read(obj.key[0][0])) $fatal(1, "null receiver return");
    if (saved_obj.key[0] !== keep0 || saved_obj.key[1] !== keep1)
      $fatal(1, "null receiver alias");
    $display("PASSED");
  end
endmodule
