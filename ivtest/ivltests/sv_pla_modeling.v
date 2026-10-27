module sv_pla_modeling;
  logic [1:4] in;
  logic [1:2] ao, oo, an, on;
  logic [1:4] mem [1:2];
  logic [1:3] plane_mem [1:4];
  logic [1:3] plane_in;
  logic [1:4] plane_out;
  logic [1:4] plane_nand, plane_or, plane_nor;
  logic [1:2] sync_and, sync_nand, sync_or, sync_nor;
  logic [1:4] sync_plane, sync_nplane, sync_oplane, sync_noplane;

  initial begin
    mem[1] = 4'b1100; mem[2] = 4'b0011;
    in = 4'b1100;
    $async$and$array(mem, in, ao);
    $async$or$array(mem, in, oo);
    $async$nand$array(mem, in, an);
    $async$nor$array(mem, in, on);
    #1;
    if (ao !== 2'b10 || oo !== 2'b10 || an !== 2'b01 || on !== 2'b01)
      $fatal(1, "PLA P1 mismatch: %b %b %b %b", ao, oo, an, on);
    $display("P1 %b %b", ao, oo);

    in = 4'b1111; #1;
    if (ao !== 2'b11 || oo !== 2'b11) $fatal(1, "PLA P2 mismatch");
    $display("P2 %b %b", ao, oo);
    in = 4'b0001; #1;
    if (ao !== 2'b00 || oo !== 2'b01) $fatal(1, "PLA P3 mismatch");
    $display("P3 %b %b", ao, oo);
    mem[2] = 4'b0001; #1;
    if (ao !== 2'b01 || oo !== 2'b01) $fatal(1, "PLA P4 mismatch");
    $display("P4 %b %b", ao, oo);

    plane_mem[1] = 3'b10z; plane_mem[2] = 3'bzz1;
    plane_mem[3] = 3'b0z0; plane_mem[4] = 3'bzzz;
    plane_in = 3'b111;
    $async$and$plane(plane_mem, plane_in[1:3], plane_out);
    $async$nand$plane(plane_mem, plane_in[1:3], plane_nand);
    $async$or$plane(plane_mem, plane_in[1:3], plane_or);
    $async$nor$plane(plane_mem, plane_in[1:3], plane_nor);
    #1;
    if (plane_out !== 4'b0101 || plane_nand !== 4'b1010 ||
        plane_or !== 4'b1100 || plane_nor !== 4'b0011)
      $fatal(1, "PLA plane logic mismatch: %b %b %b %b",
             plane_out, plane_nand, plane_or, plane_nor);
    $display("PLANE %b", plane_out);
    plane_in = 3'b000; #1;
    if (plane_out !== 4'b0011) $fatal(1, "PLA plane input change mismatch: %b", plane_out);
    $display("PLANE_INPUT %b", plane_out);
    plane_in = 3'b111;
    plane_mem[4] = 3'b000; #1;
    if (plane_out !== 4'b0100) $fatal(1, "PLA plane personality change mismatch: %b", plane_out);
    $display("PLANE_MEMORY %b", plane_out);
    plane_mem[4] = 3'bzzz;
    #1;
    plane_mem[1] = 3'bx1z; #1;
    if (plane_out !== 4'bx101) $fatal(1, "PLA plane X mismatch: %b", plane_out);
    $sync$nand$plane(plane_mem, plane_in, sync_nplane);
    if (sync_nplane !== 4'bx010) $fatal(1, "PLA plane NAND X mismatch: %b", sync_nplane);
    plane_mem[1] = 3'b10z; #1;

    sync_and = 'x; sync_nand = 'x; sync_or = 'x; sync_nor = 'x;
    $sync$and$array(mem, in, sync_and);
    $sync$nand$array(mem, in, sync_nand);
    $sync$or$array(mem, in, sync_or);
    $sync$nor$array(mem, in, sync_nor);
    if (sync_and !== 2'b01 || sync_nand !== 2'b10 ||
        sync_or !== 2'b01 || sync_nor !== 2'b10)
      $fatal(1, "PLA sync array mismatch");
    $sync$and$plane(plane_mem, plane_in[1:3], sync_plane);
    $sync$nand$plane(plane_mem, plane_in[1:3], sync_nplane);
    $sync$or$plane(plane_mem, plane_in[1:3], sync_oplane);
    $sync$nor$plane(plane_mem, plane_in[1:3], sync_noplane);
    if (sync_plane !== 4'b0101 || sync_nplane !== 4'b1010 ||
        sync_oplane !== 4'b1100 || sync_noplane !== 4'b0011)
      $fatal(1, "PLA sync plane mismatch: %b %b %b %b",
             sync_plane, sync_nplane, sync_oplane, sync_noplane);
    $display("SYNC %b %b", sync_and, sync_or);
    $display("PASSED");
  end
endmodule
