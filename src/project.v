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

    reg [7:0] w0, w1, w2, w3;
    reg [9:0] sum;
    reg [1:0] count;
    reg       ready;
    reg       alert;
    reg [7:0] mean_r;

    assign uio_oe  = 8'd0;
    assign uio_out = 8'd0;

    wire [7:0] threshold = uio_in;
    wire [7:0] mean_c    = sum[9:2];
    wire [8:0] diff_s    = {1'b0, ui_in} - {1'b0, mean_c};
    wire [7:0] diff_ab   = diff_s[8] ? (~diff_s[7:0] + 8'd1) : diff_s[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w0 <= 8'd0; w1 <= 8'd0; w2 <= 8'd0; w3 <= 8'd0;
            sum    <= 10'd0;
            count  <= 2'd0;
            ready  <= 1'b0;
            alert  <= 1'b0;
            mean_r <= 8'd0;
        end else if (ena) begin
            sum <= sum - {2'b00, w3} + {2'b00, ui_in};
            w3 <= w2; w2 <= w1; w1 <= w0; w0 <= ui_in;
            if (!ready) begin
                if (count == 2'd3) ready <= 1'b1;
                else count <= count + 1'd1;
            end
            mean_r <= mean_c;
            if (ready) alert <= (diff_ab > threshold);
            else       alert <= 1'b0;
        end
    end

    assign uo_out[0]   = alert;
    assign uo_out[1]   = ready;
    assign uo_out[7:2] = mean_r[7:2];

endmodule
