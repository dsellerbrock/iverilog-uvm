// M4B-15 / M10: whole fixed unpacked-array struct members crossing
// SystemVerilog and DPI open-array boundaries.
module m4b_struct_array_member_open_test;
  import "DPI-C" function int c_member_int(input int a[], input int left,
                                            input int right, input int base);
  import "DPI-C" function int c_member_md(input int a[][]);
  import "DPI-C" function int c_member_byte(input byte a[]);
  import "DPI-C" function int c_member_short(input shortint a[]);
  import "DPI-C" function int c_member_real(input real a[]);
  import "DPI-C" function void c_member_md_bump(inout int a[][],
                                                input int delta,
                                                output int status);
  import "DPI-C" function void c_member_bump(inout int a[], input int left,
                                             input int right, input int delta,
                                             output int status);
  import "DPI-C" function void c_member_fill(output int a[], input int left,
                                              input int right, input int base,
                                              output int status);

  typedef struct {
    int asc[3:5];
    int desc[5:3];
    int md[1:2][7:5];
    byte bytes[-1:1];
    shortint shorts[9:7];
    real reals[2:3];
  } payload_t;

  class Holder;
    payload_t data;
  endclass

  payload_t direct;
  payload_t queued_payload;
  payload_t payloads[$];
  Holder holder;
  Holder queued_holder;
  Holder holders[$];
  int payload_idx;
  int fails;
  int status;

  task check(string what, int mask);
    if (mask != 0) begin
      fails++;
      $display("FAIL %s: mask=0x%0h", what, mask);
    end
  endtask

  initial begin
    holder = new;
    queued_holder = new;
    holders.push_back(queued_holder);

    foreach (direct.asc[i]) direct.asc[i] = 100 + i;
    foreach (direct.desc[i]) direct.desc[i] = 200 + i;
    foreach (direct.md[i,j]) direct.md[i][j] = 100*i + j;
    foreach (direct.bytes[i]) direct.bytes[i] = byte'(10 + i);
    foreach (direct.shorts[i]) direct.shorts[i] = shortint'(20 + i);
    foreach (direct.reals[i]) direct.reals[i] = 0.5 + i;
    holder.data = direct;
    holders[0].data = direct;
    queued_payload = direct;
    payloads.push_back(queued_payload);
    payload_idx = 0;

    check("direct ascending input",
          c_member_int(direct.asc, 3, 5, 100));
    check("direct descending input",
          c_member_int(direct.desc, 5, 3, 200));
    check("multidimensional input", c_member_md(direct.md));
    check("byte input", c_member_byte(direct.bytes));
    check("shortint input", c_member_short(direct.shorts));
    check("real input", c_member_real(direct.reals));
    check("class-stored struct input",
          c_member_int(holder.data.asc, 3, 5, 100));
    check("container-reached struct input",
          c_member_int(holders[0].data.desc, 5, 3, 200));
    check("runtime-container struct input",
          c_member_int(payloads[payload_idx].asc, 3, 5, 100));

    c_member_bump(direct.asc, 3, 5, 1000, status);
    check("direct inout C geometry", status);
    if (direct.asc[3] != 1103 || direct.asc[5] != 1105) begin
      fails++;
      $display("FAIL direct inout copyback: %0d %0d",
               direct.asc[3], direct.asc[5]);
    end

    c_member_fill(direct.desc, 5, 3, 700, status);
    check("direct output C geometry", status);
    if (direct.desc[3] != 703 || direct.desc[5] != 705) begin
      fails++;
      $display("FAIL direct output copyback: %0d %0d",
               direct.desc[3], direct.desc[5]);
    end

    c_member_bump(holder.data.asc, 3, 5, 50, status);
    check("class inout C geometry", status);
    check("class inout copyback",
          c_member_int(holder.data.asc, 3, 5, 150));

    c_member_fill(holders[0].data.desc, 5, 3, 800, status);
    check("container output C geometry", status);
    check("container output copyback",
          c_member_int(holders[0].data.desc, 5, 3, 800));

    c_member_bump(payloads[payload_idx].asc, 3, 5, 25, status);
    check("runtime-container inout C geometry", status);
    check("runtime-container inout copyback",
          c_member_int(payloads[payload_idx].asc, 3, 5, 125));

    c_member_md_bump(direct.md, 1000, status);
    check("multidimensional inout C geometry", status);
    if (direct.md[1][7] != 1107 || direct.md[2][5] != 1205) begin
      fails++;
      $display("FAIL multidimensional inout copyback: %0d %0d",
               direct.md[1][7], direct.md[2][5]);
    end

    if (fails == 0)
      $display("PASS m4b_struct_array_member_open_test");
    else
      $display("FAIL m4b_struct_array_member_open_test (%0d)", fails);
    $finish(0);
  end
endmodule
