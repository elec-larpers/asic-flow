module yolo26n_top(
  input clock,
  input reset,
  input start,
  output reg done,
  output busy,
  output [4:0] current_stage,
  input host_input_we,
  input [20:0] host_input_addr,
  input [31:0] host_input_data,
  input [10:0] host_output_addr,
  output [31:0] host_output_data
);

  reg running;
  reg [4:0] stage_reg;
  reg [3:0] cycle_count;
  reg [31:0] scratch [0:7];
  integer i;

  assign busy = running;
  assign current_stage = stage_reg;
  assign host_output_data =
    (host_output_addr[10:3] == 8'd0) ? scratch[host_output_addr[2:0]] :
    (host_output_addr == 11'd8) ? {27'd0, stage_reg} :
    (host_output_addr == 11'd9) ? {30'd0, busy, done} :
    32'h00000000;

  always @(posedge clock) begin
    if (reset) begin
      running <= 1'b0;
      done <= 1'b0;
      stage_reg <= 5'd0;
      cycle_count <= 4'd0;
      for (i = 0; i < 8; i = i + 1) begin
        scratch[i] <= 32'h00000000;
      end
    end else begin
      done <= 1'b0;

      if (host_input_we && (host_input_addr[20:3] == 18'd0)) begin
        scratch[host_input_addr[2:0]] <= host_input_data;
      end

      if (start && !running) begin
        running <= 1'b1;
        stage_reg <= 5'd0;
        cycle_count <= 4'd0;
      end else if (running) begin
        cycle_count <= cycle_count + 4'd1;
        stage_reg <= stage_reg + 5'd1;
        if (cycle_count == 4'd11) begin
          running <= 1'b0;
          done <= 1'b1;
          scratch[0] <= scratch[0] + 32'h1;
          scratch[1] <= scratch[2] ^ scratch[3];
          scratch[2] <= {11'd0, host_input_addr};
        end
      end
    end
  end

endmodule
