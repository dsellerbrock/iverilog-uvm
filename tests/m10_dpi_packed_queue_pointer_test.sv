// IEEE 1800-2017 Annex H: a packed-element queue actual has no whole-array
// C layout, but each in-range element must have stable canonical storage for
// the dynamic extent of the DPI call. Pointer and canonical-copy accessors
// must observe the same value, with output/inout changes copied back.
module m10_dpi_packed_queue_pointer_test;
  import "DPI-C" function int check_queue_bytes(input bit [7:0] data[]);
  import "DPI-C" function int mutate_queue_bytes(inout bit [7:0] data[]);
  import "DPI-C" function int mutate_queue_wide(inout bit [39:0] data[]);
  import "DPI-C" function int mutate_queue_logic(inout logic [3:0] data[]);

  bit [7:0] data[$];
  bit [39:0] wide[$];
  logic [3:0] logic_data[$];
  int status;

  initial begin
    data.push_back(8'h12);
    data.push_back(8'ha5);
    data.push_back(8'h5a);
    status = check_queue_bytes(data);
    if (status != 0)
      $fatal(1, "queue byte DPI pointer status=%0d", status);
    status = mutate_queue_bytes(data);
    if (status != 0 || data.size() != 3 || data[0] != 8'he1 ||
        data[1] != 8'h3c || data[2] != 8'he2)
      $fatal(1, "queue byte DPI copyback status=%0d data=%p", status, data);

    wide.push_back(40'h12_3456_789a);
    wide.push_back(40'h00_0000_0000);
    status = mutate_queue_wide(wide);
    if (status != 0 || wide[0] != 40'h55_89ab_cdef ||
        wide[1] != 40'haa_0123_4567)
      $fatal(1, "queue wide DPI copyback status=%0d data=%p", status, wide);

    logic_data.push_back(4'b1xz0);
    status = mutate_queue_logic(logic_data);
    if (status != 0 || logic_data[0] !== 4'b0xz1)
      $fatal(1, "queue logic DPI copyback status=%0d data=%p",
             status, logic_data);

    $display("PASS m10_dpi_packed_queue_pointer_test");
    $finish;
  end
endmodule
