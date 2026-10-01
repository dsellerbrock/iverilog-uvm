// IEEE 1800-2017/2023 7.4, 7.8: OpenTitan flash_ctrl stores enum-keyed
// fixed arrays; reads, writes, copies, and deletes preserve each key's value.
module top;
  typedef enum bit { Data, Info } part_t;
  bit [7:0] tgt[part_t][3:2];
  logic [1:0] four[part_t][3:2];
  bit [7:0] ascending[int][2:3];

  initial begin
    if (tgt.exists(Data) || tgt.exists(Info)) $fatal(1, "initial keys");
    if (tgt[Data][2] !== 8'h00 || tgt.exists(Data))
      $fatal(1, "absent-key read changed the map");
    if (four[Data][2] !== 2'bxx || four.exists(Data))
      $fatal(1, "absent 4-state leaf default");
    four[Data][3] = 2'b01;
    if (four[Data][2] !== 2'bxx || four[Data][3] !== 2'b01)
      $fatal(1, "new entry lost untouched 4-state leaf");
    tgt[Data][2] = 8'hA5;
    tgt[Info][3] = 8'h5A;
    if (!tgt.exists(Data) || !tgt.exists(Info)
        || tgt[Data][2] !== 8'hA5 || tgt[Data][3] !== 8'h00
        || tgt[Info][2] !== 8'h00 || tgt[Info][3] !== 8'h5A)
      $fatal(1, "fixed slots or per-key storage");
    tgt[Info] = tgt[Data];
    tgt[Data][2] = 8'h3C;
    if (tgt[Info][2] !== 8'hA5 || tgt[Info][3] !== 8'h00)
      $fatal(1, "aggregate assignment aliased an entry");
    tgt.delete(Data);
    if (tgt.exists(Data) || !tgt.exists(Info)
        || tgt[Info][2] !== 8'hA5)
      $fatal(1, "deletion changed another entry");
    tgt[Data] = tgt[Info];
    tgt[Info][2] = 8'h7E;
    if (!tgt.exists(Data) || tgt[Data][2] !== 8'hA5
        || tgt[Data][3] !== 8'h00)
      $fatal(1, "whole array assignment into absent key");
    ascending[11][2] = 8'h12;
    ascending[11][3] = 8'h34;
    ascending[12] = ascending[11];
    if (ascending[11][2] !== 8'h12 || ascending[11][3] !== 8'h34
        || ascending[12][2] !== 8'h12 || ascending[12][3] !== 8'h34)
      $fatal(1, "ascending fixed bounds");
    $display("PASSED");
  end
endmodule
