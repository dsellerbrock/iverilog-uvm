// IEEE 1800-2017/2023: a selected field retains its fixed-array element.
typedef enum logic [3:0] { MuBiFalse = 4'h9, MuBiTrue = 4'h6 } mubi_t;
typedef struct packed {
  mubi_t en;
  mubi_t read_en;
  mubi_t program_en;
  mubi_t erase_en;
  mubi_t scramble_en;
  mubi_t ecc_en;
  mubi_t he_en;
  int unsigned num_pages;
  int unsigned start_page;
} region_t;

class region_holder;
  rand region_t regions[3:2];
  rand mubi_t en;
  bit contradict;
  constraint c {
    en == MuBiFalse;
    foreach (regions[i]) {
      regions[i].en == (i == 3 ? MuBiTrue : MuBiFalse);
      regions[i].read_en == (i == 3 ? MuBiFalse : MuBiTrue);
      regions[i].program_en == (i == 3 ? MuBiTrue : MuBiFalse);
      regions[i].he_en == MuBiTrue;
      regions[i].start_page == i;
    }
    regions[2].num_pages == 32'd17;
    regions[3].num_pages == 32'd29;
    if (contradict) regions[2].en == MuBiTrue;
  }
endclass

module test;
  region_holder item;
  region_t saved_two, saved_three;
  initial begin
    item = new;
    if (!item.randomize() || item.en !== MuBiFalse
        || item.regions[2].en !== MuBiFalse
        || item.regions[3].en !== MuBiTrue
        || item.regions[2].read_en !== MuBiTrue
        || item.regions[3].read_en !== MuBiFalse
        || item.regions[2].program_en !== MuBiFalse
        || item.regions[3].program_en !== MuBiTrue
        || item.regions[2].he_en !== MuBiTrue
        || item.regions[3].he_en !== MuBiTrue
        || item.regions[2].num_pages !== 17
        || item.regions[3].num_pages !== 29
        || item.regions[2].start_page !== 2
        || item.regions[3].start_page !== 3)
      $fatal(1, "indexed packed member mismatch");
    saved_two = item.regions[2];
    saved_three = item.regions[3];
    item.contradict = 1;
    if (item.randomize() || item.regions[2] !== saved_two
        || item.regions[3] !== saved_three)
      $fatal(1, "contradictory packed member changed state");
    $display("PASSED");
  end
endmodule
