// A concatenation l-value whose targets are dynamic-array elements:
//   {data[3], data[2], data[1], data[0]} = {ep, seq_id[27:0]};
// where `byte unsigned data[]`.  vvp codegen bailed with
//   "sorry: multi-lval assignment with a dynamic-array element ..."
// because show_stmt_assign only handled a single darray l-value, and the
// generic vector distribution can't be reused (ivl_lval_width reports 1 for
// a darray element reference).
//
// The fix adds show_stmt_assign_darray_concat: it derives each element's
// width from the darray element type, evaluates the r-value once, and splits
// it across the elements LSB-first (l-value 0 is the least-significant
// element), storing each piece with %store/dar/vec4.  This is the OpenTitan
// usbdev_max_usb_traffic_vseq pattern.
module concat_lval_darray_element_test;
  initial begin
    byte unsigned data[];
    bit  [3:0]  ep      = 4'hA;
    bit  [31:0] seq_id  = 32'h0123_4567;
    logic [15:0] lr[];
    int i0 = 0, i1 = 1;       // runtime indices

    data = new[4];
    // 32-bit RHS = {ep, seq_id[27:0]} = {4'hA, 28'h1234567} = 0xA1234567
    {data[3], data[2], data[1], data[0]} = {ep, seq_id[27:0]};
    // MSB-first: data[3]=0xA1, data[2]=0x23, data[1]=0x45, data[0]=0x67

    // Runtime (variable) element indices: the index evaluation must not
    // disturb the vec4 value on the stack.  2x 16-bit elements, total 32;
    // a 16-bit RHS is zero-extended: {lr[1],lr[0]} = 32'h0000CAFE.
    lr = new[2];
    {lr[i1], lr[i0]} = 16'hCAFE;

    if (data[3]==8'hA1 && data[2]==8'h23 && data[1]==8'h45 && data[0]==8'h67 &&
        lr[1]==16'h0000 && lr[0]==16'hCAFE)
      $display("PASS data=%02h_%02h_%02h_%02h lr=%04h_%04h",
               data[3], data[2], data[1], data[0], lr[1], lr[0]);
    else
      $display("FAIL data=%02h_%02h_%02h_%02h lr=%04h_%04h",
               data[3], data[2], data[1], data[0], lr[1], lr[0]);
    $finish;
  end
endmodule
