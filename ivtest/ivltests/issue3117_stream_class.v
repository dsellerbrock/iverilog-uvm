// IEEE 1800-2023 11.4.14.1: a non-null class handle streams the data
// members of the referenced object in declaration order, base-class
// members first; a null handle (also a nested one) is skipped.
class issue3117_P; byte first; byte second; endclass
class issue3117_B; byte b0 = 8'h11; endclass
class issue3117_D extends issue3117_B; byte d0 = 8'h22; bit [3:0] d1 = 4'h3; endclass
class issue3117_N; byte n0 = 8'h44; issue3117_P inner; byte n1 = 8'h55; endclass

module issue3117_stream_class;
  issue3117_P p, pn;
  issue3117_D d;
  issue3117_B b;
  issue3117_N n;
  bit [15:0] w;
  bit [19:0] w20;
  bit [23:0] w24;
  bit [31:0] w32;
  initial begin
    p = new; p.first = 8'h69; p.second = 8'hd2;
    w = {>>{p}};                 $display("%h", w);
    d = new; w20 = {>>{d}};      $display("%h", w20);
    b = d;   w20 = {>>{b}};      $display("%h", w20);   // runtime type D
    w24 = {>>{8'hab, p}};        $display("%h", w24);
    w24 = {>>{pn, 8'hcd, p}};    $display("%h", w24);   // null pn skipped
    n = new; w32 = {>>{n}};      $display("%h", w32);   // null inner skipped: left-aligned
    n.inner = p; w32 = {>>{n}};  $display("%h", w32);
  end
endmodule
