module test;
  int src_d [7:0];
  int dst_d [7:0];
  int src_a [0:7];
  int dst_a [0:7];
  int overlap [7:0];
  int nb_src [7:0];
  int nb_dst [7:0];
  int whole [2:0];
  logic four_a [3:0];
  logic four_b [3:0];
  integer i;

  task automatic fail(string what);
    $display("FAILED: %s", what);
    $finish(1);
  endtask

  initial begin
    for (i = 0; i < 8; i = i + 1) begin
      src_d[i] = 100 + i;
      src_a[i] = 200 + i;
      dst_d[i] = -1;
      dst_a[i] = -1;
      overlap[i] = i;
      nb_src[i] = 300 + i;
      nb_dst[i] = -1;
    end

    dst_d[5:3] = src_d[2:0];
    if (dst_d[5] != 102 || dst_d[4] != 101 || dst_d[3] != 100)
      fail("descending explicit slice");

    dst_a[2:4] = src_a[5:7];
    if (dst_a[2] != 205 || dst_a[3] != 206 || dst_a[4] != 207)
      fail("ascending explicit slice");

    dst_d[5:3] = src_a[2:4];
    if (dst_d[5] != 202 || dst_d[4] != 203 || dst_d[3] != 204)
      fail("opposite-direction slice assignment");

    dst_d[1 +: 3] = src_d[4 +: 3];
    if (dst_d[3] != 106 || dst_d[2] != 105 || dst_d[1] != 104)
      fail("descending indexed plus slice");

    dst_a[5 -: 3] = src_a[4 -: 3];
    if (dst_a[3] != 202 || dst_a[4] != 203 || dst_a[5] != 204)
      fail("ascending indexed minus slice");

    whole = src_a[2:4];
    if (whole[2] != 202 || whole[1] != 203 || whole[0] != 204)
      fail("slice to whole assignment");
    if (!(whole == src_a[2:4]) || whole != src_a[2:4])
      fail("opposite-direction slice comparison");
    dst_a[2:4] = whole;
    if (dst_a[2] != 202 || dst_a[3] != 203 || dst_a[4] != 204)
      fail("whole to slice assignment");

    overlap[5:3] = overlap[4:2];
    if (overlap[5] != 4 || overlap[4] != 3 || overlap[3] != 2)
      fail("overlapping blocking snapshot");

    if (!(src_d[2:0] == src_d[2:0]))
      fail("slice equality");
    if (src_d[2:0] != src_d[2:0])
      fail("slice inequality");
    if (!(src_d[4 +: 3] == src_d[6:4]))
      fail("indexed slice equality");

    four_a = '{1'b1, 1'bx, 1'b0, 1'b1};
    four_b = four_a;
    if ((four_a[3:1] == four_b[3:1]) !== 1'bx)
      fail("four-state logical equality");
    if (!(four_a[3:1] === four_b[3:1]))
      fail("four-state case equality");
    four_b[2] = 1'b0;
    if (four_a[3:1] === four_b[3:1])
      fail("four-state case inequality");

    nb_dst[5:3] <= nb_src[2:0];
    nb_src[2] = 902;
    nb_src[1] = 901;
    nb_src[0] = 900;
    #0;
    if (nb_dst[5] != -1 || nb_dst[4] != -1 || nb_dst[3] != -1)
      fail("NBA updated before NBA region");
    #1;
    if (nb_dst[5] != 302 || nb_dst[4] != 301 || nb_dst[3] != 300)
      fail("NBA source snapshot");

    $display("PASSED");
  end
endmodule
