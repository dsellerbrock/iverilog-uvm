// Legal IEEE 1800-2017/2023 subarray copies (7.4.4, 7.6) whose destination
// or source is a class property. These were loud sorries until #2658; now
// they copy element by element.
module test;
  class holder_t;
    logic [7:0] words [2];
    logic [7:0] grid [1:0][2];
  endclass
  holder_t holder;
  logic [7:0] src [2][2];
  logic [7:0] dst [2];
  bit failed = 0;
  initial begin
    holder = new;
    src[0][0] = 8'h11; src[0][1] = 8'h22; src[1][0] = 8'h33; src[1][1] = 8'h44;
    holder.words = src[0];
    if (holder.words[0] !== 8'h11 || holder.words[1] !== 8'h22) begin
      $display("FAILED dest: %h %h", holder.words[0], holder.words[1]); failed = 1;
    end
    holder.words = src[1];
    if (holder.words[0] !== 8'h33 || holder.words[1] !== 8'h44) begin
      $display("FAILED dest 2: %h %h", holder.words[0], holder.words[1]); failed = 1;
    end
    holder.grid[0][0] = 8'h55; holder.grid[0][1] = 8'h66;
    holder.grid[1][0] = 8'h77; holder.grid[1][1] = 8'h88;
    dst = holder.grid[0];
    if (dst[0] !== 8'h55 || dst[1] !== 8'h66) begin
      $display("FAILED src: %h %h", dst[0], dst[1]); failed = 1;
    end
    dst = holder.grid[1];
    if (dst[0] !== 8'h77 || dst[1] !== 8'h88) begin
      $display("FAILED src 2: %h %h", dst[0], dst[1]); failed = 1;
    end
    if (!failed) $display("PASSED");
  end
endmodule
