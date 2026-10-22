module sv_readmem_darray_queue;
  logic [7:0] darray[];
  logic [7:0] queue[$];
  logic [7:0] roundtrip[0:1];
  integer fd;

  initial begin
    darray = new[2];
    queue.push_back(0);
    queue.push_back(0);

    fd = $fopen("work/sv_readmem_darray_queue.hex", "w");
    if (fd == 0) $fatal(1, "could not create input file");
    $fdisplay(fd, "12");
    $fdisplay(fd, "34");
    $fdisplay(fd, "56");
    $fclose(fd);

    $readmemh("work/sv_readmem_darray_queue.hex", darray);
    $readmemh("work/sv_readmem_darray_queue.hex", queue);
    if (darray.size() != 2 || queue.size() != 2 ||
        darray[0] !== 8'h12 || darray[1] !== 8'h34 ||
        queue[0] !== 8'h12 || queue[1] !== 8'h34)
      $fatal(1, "readmemh changed array size or loaded wrong data");

    $writememh("work/sv_readmem_darray_queue_array.out", darray);
    $readmemh("work/sv_readmem_darray_queue_array.out", roundtrip);
    if (roundtrip[0] !== 8'h12 || roundtrip[1] !== 8'h34)
      $fatal(1, "dynamic-array writememh round trip failed");

    $writememh("work/sv_readmem_darray_queue_queue.out", queue);
    $readmemh("work/sv_readmem_darray_queue_queue.out", roundtrip);
    if (roundtrip[0] !== 8'h12 || roundtrip[1] !== 8'h34)
      $fatal(1, "queue writememh round trip failed");

    $display("PASSED");
    $finish;
  end
endmodule
