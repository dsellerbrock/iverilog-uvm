// IEEE 1800-2017/2023 35.5.6.1 and Annex H.7.8, H.12.
module test;
  typedef struct { byte tag; int data; logic flag; } item_t;
  typedef struct { byte tag; string text; real data; } text_item_t;

  import "DPI-C" function int issue3917_fill(output item_t a[][]);
  import "DPI-C" function int issue3917_update(inout item_t a[][]);
  import "DPI-C" function int issue3917_swap_text(inout text_item_t a[][][]);
  import "DPI-C" function int issue3917_rank4(input item_t a[][][][]);
  import "DPI-C" function int issue3917_dynamic(output item_t a[][], input int rows);

  item_t values[2:1][-2:0];
  text_item_t texts[2:1][-1:-1][0:1];
  item_t tensor[3:4][1:1][0:-1][10:11];
  item_t dynamic_values[][];

  task automatic check_values(input bit updated);
    for (int i = 1; i <= 2; ++i) begin
      for (int j = -2; j <= 0; ++j) begin
        byte tag_expected;
        int data_expected;
        logic flag_expected;
        tag_expected = -10 * i + j;
        data_expected = 1000 * i + j;
        flag_expected = (j == -1) ? 1'b1 : ((i == 2) ? 1'bx : 1'bz);
        if (updated && i == 2 && j == -2) begin
          data_expected = -12345;
          flag_expected = 1'bz;
        end
        if (updated && i == 1 && j == 0) begin
          tag_expected = 49;
          flag_expected = 1'bx;
        end
        if (values[i][j].tag !== tag_expected ||
            values[i][j].data !== data_expected ||
            values[i][j].flag !== flag_expected)
          $fatal(1, "copyback at [%0d][%0d] after update=%0d", i, j, updated);
      end
    end
  endtask

  initial begin
    if (!issue3917_fill(values)) $fatal(1, "numeric output bounds or stride");
    check_values(0);
    if (!issue3917_update(values)) $fatal(1, "numeric inout values or bounds");
    check_values(1);

    texts[2][-1][0] = '{7, "a longer string from the first row", 1.25};
    texts[1][-1][1] = '{8, "last", 2.5};
    texts[1][-1][0] = '{9, "untouched", 3.75};
    if (!issue3917_swap_text(texts)) $fatal(1, "string member layout or bounds");
    if (texts[2][-1][0].tag !== 7 || texts[2][-1][0].data != 1.25 ||
        texts[2][-1][0].text != "last" ||
        texts[1][-1][1].tag !== 8 || texts[1][-1][1].data != 2.5 ||
        texts[1][-1][1].text != "a longer string from the first row" ||
        texts[1][-1][0].text != "untouched" || texts[2][-1][1].text != "")
      $fatal(1, "string pointer swap across rows");

    tensor[4][1][-1][11] = '{-4, 42, 1'bz};
    if (!issue3917_rank4(tensor)) $fatal(1, "rank-four variadic access");

    if (!issue3917_dynamic(dynamic_values, 0)) $fatal(1, "unallocated actual");
    dynamic_values = new[1];
    dynamic_values[0] = new[2];
    if (!issue3917_dynamic(dynamic_values, 1)) $fatal(1, "dynamic output access");
    if (dynamic_values[0][0].tag !== -1 || dynamic_values[0][0].data !== 27 ||
        dynamic_values[0][0].flag !== 1'bz ||
        dynamic_values[0][1].tag !== 2 || dynamic_values[0][1].data !== -81 ||
        dynamic_values[0][1].flag !== 1'bx)
      $fatal(1, "dynamic output into default elements");
    $display("PASSED");
  end
endmodule
