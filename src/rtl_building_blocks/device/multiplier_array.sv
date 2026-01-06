module multiplier_array #(
  parameter int OUT_SCALE = 16
  )
  (
  input  logic signed [47:0] kernel  [0:2],
  input  logic signed [47:0] data    [0:2],
  output logic signed [47:0] product [0:2]
  );
    
  // Multiplier instances for ky0 (row 0)
  multiplier #( .A_WIDTH(16), .B_WIDTH(16), .OUT_WIDTH(16), .OUT_SCALE(16)) mul_kx0_ky0 (
      .a(data[0][15:0]),
      .b(kernel[0][15:0]),
      .out(product[0][15:0])
  );
  multiplier #( .A_WIDTH(16), .B_WIDTH(16), .OUT_WIDTH(16), .OUT_SCALE(16)) mul_kx1_ky0 (
      .a(data[0][31:16]),
      .b(kernel[0][31:16]),
      .out(product[0][31:16])
  );
  multiplier #( .A_WIDTH(16), .B_WIDTH(16), .OUT_WIDTH(16), .OUT_SCALE(16)) mul_kx2_ky0 (
      .a(data[0][47:32]),
      .b(kernel[0][47:32]),
      .out(product[0][47:32])
  );

  // Multiplier instances for ky1 (row 1)
  multiplier #( .A_WIDTH(16), .B_WIDTH(16), .OUT_WIDTH(16), .OUT_SCALE(16)) mul_kx0_ky1 (
      .a(data[1][15:0]),
      .b(kernel[1][15:0]),
      .out(product[1][15:0])
  );
  multiplier #( .A_WIDTH(16), .B_WIDTH(16), .OUT_WIDTH(16), .OUT_SCALE(16)) mul_kx1_ky1 (
      .a(data[1][31:16]),
      .b(kernel[1][31:16]),
      .out(product[1][31:16])
  );
  multiplier #( .A_WIDTH(16), .B_WIDTH(16), .OUT_WIDTH(16), .OUT_SCALE(16)) mul_kx2_ky1 (
      .a(data[1][47:32]),
      .b(kernel[1][47:32]),
      .out(product[1][47:32])
  );

  // Multiplier instances for ky2 (row 2)
  multiplier #( .A_WIDTH(16), .B_WIDTH(16), .OUT_WIDTH(16), .OUT_SCALE(16)) mul_kx0_ky2 (
      .a(data[2][15:0]),
      .b(kernel[2][15:0]),
      .out(product[2][15:0])
  );
  multiplier #( .A_WIDTH(16), .B_WIDTH(16), .OUT_WIDTH(16), .OUT_SCALE(16)) mul_kx1_ky2 (
      .a(data[2][31:16]),
      .b(kernel[2][31:16]),
      .out(product[2][31:16])
  );
  multiplier #( .A_WIDTH(16), .B_WIDTH(16), .OUT_WIDTH(16), .OUT_SCALE(16)) mul_kx2_ky2 (
      .a(data[2][47:32]),
      .b(kernel[2][47:32]),
      .out(product[2][47:32])
  );


endmodule
