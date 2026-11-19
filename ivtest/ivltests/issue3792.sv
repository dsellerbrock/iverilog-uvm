module issue3792_child(inout wire p[2]);
  assign (weak0, weak1) p[0] = 1'b0;
endmodule

module issue3792_scalar(inout wire [1:0] p);
  assign (weak0, weak1) p[0] = 1'b0;
endmodule

module issue3792;
  wire a[2][2];
  issue3792_child c[0:1](a);
  reg drive = 1;
  assign (strong0, strong1) a[0][0] = drive ? 1'b1 : 1'bz;

  wire selected[4:3][9:8][13:12];
  issue3792_child rows[0:1](selected[4]);
  assign selected[4][9][13] = 1'b1;
  assign selected[4][8][12] = 1'b1;

  wire strided[5:2][7:6][0:1];
  issue3792_child slice[9:8](strided[4 -: 2][6]);
  assign strided[3][6][0] = 1'b1;

  wire single[5:4];
  issue3792_child one(single);
  assign single[4] = 1'b1;

  wire shared[3:4];
  issue3792_child broadcast[9:8](shared);
  assign shared[3] = 1'b1;

  wire singleton[5:5][4:3];
  issue3792_child only_instance[1:1](singleton);
  assign singleton[5][4] = 1'b1;

  wire #3 delayed[2];
  issue3792_child delayed_child(delayed);
  reg drive_delayed = 0;
  assign delayed_child.p[0] = drive_delayed ? 1'b1 : 1'bz;

  wire [1:0] scalar_whole[3:2];
  issue3792_scalar whole[0:1](scalar_whole);
  assign scalar_whole[2][1] = 1'b1;

  wire [1:0] scalar[3:2][0:3];
  issue3792_scalar scalars[9:8](scalar[3][1 +: 2]);
  issue3792_scalar packed_actual[0:1](scalar[2][2]);
  assign scalar[3][1] = 2'b11;
  assign scalar[3][2][1] = 1'b1;
  assign scalar[2][2][1] = 1'b1;

  initial begin
    #1;
    if ({c[0].p[0], c[1].p[0], a[0][0], a[1][0]} !== 4'b1010 ||
        {a[0][1], a[1][1], c[0].p[1], c[1].p[1]} !== 4'bzzzz ||
        $sformatf("%v", a[1][0]) != "We0")
      $fatal(1, "wrong value or strength on whole inout array");

    if ({rows[0].p[0], rows[0].p[1], rows[1].p[0], rows[1].p[1]}
        !== 4'b1z01 ||
        {selected[4][8][13], selected[3][8][13], selected[4][9][12]}
        !== 3'b0zz)
      $fatal(1, "wrong mapping of descending selected row");

    if ({slice[9].p[0], slice[8].p[0], strided[4][6][0], strided[3][6][0]}
        !== 4'b0101 ||
        {strided[4][7][0], strided[2][6][0], strided[5][6][0]}
        !== 3'bzzz)
      $fatal(1, "wrong mapping of strided selection");

    if ({one.p[0], one.p[1], single[5], single[4]} !== 4'b0101 ||
        {broadcast[9].p[0], broadcast[8].p[0], shared[3], shared[4]}
        !== 4'b111z ||
        {only_instance[1].p[0], singleton[5][4], singleton[5][3]} !== 3'b11z)
      $fatal(1, "wrong ordinary, broadcast, or singleton connection");

    if ({scalars[9].p, scalars[8].p, scalar[3][2], scalar[3][3]}
        !== 8'b111010zz ||
        {packed_actual[0].p, packed_actual[1].p, scalar[2][2]} !== 6'b101010 ||
        {whole[0].p, whole[1].p, scalar_whole[3], scalar_whole[2]} !== 8'bz010z010)
      $fatal(1, "wrong scalar formal mapping");

    drive = 0;
    #1;
    if (c[0].p[0] !== 1'b0 || $sformatf("%v", a[0][0]) != "We0")
      $fatal(1, "parent release did not expose the weak child drive");

    #2;
    if ({delayed[0], delayed[1]} !== 2'b0z)
      $fatal(1, "delayed inout lost the child drive");
    drive_delayed = 1;
    #1;
    if ({delayed[0], delayed_child.p[0]} !== 2'b01)
      $fatal(1, "inout drive bypassed net declaration delay");
    #3;
    if ({delayed[0], delayed[1]} !== 2'b1z)
      $fatal(1, "delayed inout lost the updated child drive");
    $display("PASSED");
  end
endmodule
