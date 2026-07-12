module qlearning_control #(
    parameter RUN_CYCLES = 6
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    output reg en_regs,
    output reg wr_table,
    output reg busy,
    output reg done
);

    localparam IDLE       = 2'd0;
    localparam RUN        = 2'd1;
    localparam WRITE_BACK = 2'd2;
    localparam DONE       = 2'd3;

    reg [1:0] state;
    reg [3:0] count;

    always @(*) begin
        en_regs  = 1'b0;
        wr_table = 1'b0;
        busy     = 1'b0;
        done     = 1'b0;

        case (state)
            IDLE: begin
                en_regs  = 1'b0;
                wr_table = 1'b0;
                busy     = 1'b0;
                done     = 1'b0;
            end

            RUN: begin
                en_regs  = 1'b1;
                wr_table = 1'b0;
                busy     = 1'b1;
                done     = 1'b0;
            end

            WRITE_BACK: begin
                en_regs  = 1'b0;
                wr_table = 1'b1;
                busy     = 1'b1;
                done     = 1'b0;
            end

            DONE: begin
                en_regs  = 1'b0;
                wr_table = 1'b0;
                busy     = 1'b0;
                done     = 1'b1;
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    count <= 0;

                    if (start) begin
                        state <= RUN;
                    end
                end

                RUN: begin
                    if (count == RUN_CYCLES - 1) begin
                        count <= 0;
                        state <= WRITE_BACK;
                    end else begin
                        count <= count + 4'd1;
                    end
                end

                WRITE_BACK: begin
                    state <= DONE;
                end

                DONE: begin
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    count <= 0;
                end
            endcase
        end
    end

endmodule