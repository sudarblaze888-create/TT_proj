`default_nettype none

module tt_um_anomaly_detector (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    reg [7:0] window [0:3];
    reg [1:0] wr_ptr;
    reg [2:0] count;
    reg [9:0] sum;
    reg [7:0] mean;
    reg       alert;
    reg       ready;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 4; i = i + 1) window[i] <= 0;
            wr_ptr <= 0;
            count  <= 0;
            sum    <= 0;
            mean   <= 0;
            alert  <= 0;
            ready  <= 0;
        end else if (ena) begin
            // Compute new sum (combinatorially referenced below)
            sum    <= sum - window[wr_ptr] + ui_in;
            window[wr_ptr] <= ui_in;
            wr_ptr <= (wr_ptr == 2'd3) ? 2'd0 : wr_ptr + 1;

            if (count < 3'd4) count <= count + 1;

            if (count == 3'd3) begin
                // 4th sample arriving NOW: window is about to be full
                ready <= 1;
            end

            if (count >= 3'd3) begin
                // Update mean from new sum
                mean <= (sum - window[wr_ptr] + ui_in) >> 2;
                // Compare new input against OLD mean (before this sample)
                // Use 9-bit subtraction to avoid unsigned underflow
                alert <= ( ({1'b0, ui_in} > {1'b0, mean})
                           ? (ui_in - mean)
                           : (mean  - ui_in) ) > uio_in;
            end else begin
                alert <= 0;
                ready <= 0;
            end
        end
    end

    assign uo_out[0]   = alert;
    assign uo_out[1]   = ready;
    assign uo_out[7:2] = mean[7:2];

endmodule
