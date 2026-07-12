`timescale 1ns/1ps

module cache_hierarchy_l1_lru_l2_ql #(
    parameter ADDR_WIDTH = 16
)(
    input  wire clk,
    input  wire rst,

    input  wire req,
    input  wire [ADDR_WIDTH-1:0] addr,

    output reg done,
    output reg l1_hit,
    output reg l2_hit,
    output reg mem_access,

    output reg [31:0] total_access_count,
    output reg [31:0] l1_hit_count,
    output reg [31:0] l1_miss_count,
    output reg [31:0] l2_hit_count,
    output reg [31:0] mem_access_count,
    output reg [31:0] qlearning_call_count
);

    reg [ADDR_WIDTH-1:0] addr_reg;

    reg l1_req;
    reg l1_fill_en;

    wire l1_done;
    wire l1_hit_w;
    wire l1_miss_w;

    reg l2_req;

    wire l2_done;
    wire l2_hit_w;
    wire l2_miss_w;
    wire l2_mem_access_w;

    wire l2_q_start_w;
    wire l2_q_done_w;
    wire [2:0] l2_q_victim_way_w;

    // ============================================================
    // L1: 4 KB, 2 vias, bloco de 32 bytes
    //
    // Capacidade = conjuntos × vias × tamanho do bloco
    // Capacidade = 64 × 2 × 32 = 4096 bytes = 4 KB
    //
    // INDEX_BITS  = 6  -> 2^6 = 64 conjuntos
    // OFFSET_BITS = 5  -> 2^5 = 32 bytes por bloco
    // ============================================================
    cache_l1_lru #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .INDEX_BITS(6),
        .OFFSET_BITS(5)
    ) l1 (
        .clk(clk),
        .rst(rst),
        .req(l1_req),
        .addr(addr_reg),
        .fill_en(l1_fill_en),
        .fill_addr(addr_reg),
        .done(l1_done),
        .hit(l1_hit_w),
        .miss(l1_miss_w)
    );

    // ============================================================
    // L2: 32 KB, 8 vias, bloco de 64 bytes
    //
    // Capacidade = conjuntos × vias × tamanho do bloco
    // Capacidade = 64 × 8 × 64 = 32768 bytes = 32 KB
    //
    // INDEX_BITS  = 6  -> 2^6 = 64 conjuntos
    // OFFSET_BITS = 6  -> 2^6 = 64 bytes por bloco
    // WAYS        = 8  -> 8 vias
    // ============================================================
    cache_l2_ql_8way #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .INDEX_BITS(6),
        .OFFSET_BITS(6),
        .WAYS(8)
    ) l2 (
        .clk(clk),
        .rst(rst),
        .req(l2_req),
        .addr(addr_reg),
        .done(l2_done),
        .hit(l2_hit_w),
        .miss(l2_miss_w),
        .mem_access(l2_mem_access_w),
        .q_start_dbg(l2_q_start_w),
        .q_done_dbg(l2_q_done_w),
        .q_victim_way_dbg(l2_q_victim_way_w)
    );

    localparam H_IDLE     = 3'd0;
    localparam H_L1_REQ   = 3'd1;
    localparam H_L1_WAIT  = 3'd2;
    localparam H_L2_REQ   = 3'd3;
    localparam H_L2_WAIT  = 3'd4;
    localparam H_L1_FILL  = 3'd5;
    localparam H_RESPOND  = 3'd6;

    reg [2:0] fsm;

    reg saved_l2_hit;
    reg saved_mem_access;

    always @(posedge clk) begin
        if (rst) begin
            fsm <= H_IDLE;

            addr_reg <= {ADDR_WIDTH{1'b0}};

            l1_req <= 1'b0;
            l1_fill_en <= 1'b0;
            l2_req <= 1'b0;

            done <= 1'b0;
            l1_hit <= 1'b0;
            l2_hit <= 1'b0;
            mem_access <= 1'b0;

            saved_l2_hit <= 1'b0;
            saved_mem_access <= 1'b0;

            total_access_count <= 32'd0;
            l1_hit_count <= 32'd0;
            l1_miss_count <= 32'd0;
            l2_hit_count <= 32'd0;
            mem_access_count <= 32'd0;
            qlearning_call_count <= 32'd0;

        end else begin
            // sinais pulsados: por padrão ficam em 0
            l1_req <= 1'b0;
            l1_fill_en <= 1'b0;
            l2_req <= 1'b0;

            done <= 1'b0;
            l1_hit <= 1'b0;
            l2_hit <= 1'b0;
            mem_access <= 1'b0;

            // conta quantas vezes o Q-Learning foi acionado pela L2
            if (l2_q_start_w) begin
                qlearning_call_count <= qlearning_call_count + 1;
            end

            case (fsm)

                H_IDLE: begin
                    if (req) begin
                        addr_reg <= addr;
                        total_access_count <= total_access_count + 1;
                        fsm <= H_L1_REQ;
                    end
                end

                H_L1_REQ: begin
                    l1_req <= 1'b1;
                    fsm <= H_L1_WAIT;
                end

                H_L1_WAIT: begin
                    if (l1_done) begin
                        if (l1_hit_w) begin
                            done <= 1'b1;
                            l1_hit <= 1'b1;
                            l1_hit_count <= l1_hit_count + 1;
                            fsm <= H_IDLE;
                        end else begin
                            l1_miss_count <= l1_miss_count + 1;
                            fsm <= H_L2_REQ;
                        end
                    end
                end

                H_L2_REQ: begin
                    l2_req <= 1'b1;
                    fsm <= H_L2_WAIT;
                end

                H_L2_WAIT: begin
                    if (l2_done) begin
                        saved_l2_hit <= l2_hit_w;
                        saved_mem_access <= l2_mem_access_w;

                        if (l2_hit_w) begin
                            l2_hit_count <= l2_hit_count + 1;
                        end

                        if (l2_mem_access_w) begin
                            mem_access_count <= mem_access_count + 1;
                        end

                        fsm <= H_L1_FILL;
                    end
                end

                // Faz o preenchimento da L1 depois que o bloco veio da L2/memória
                H_L1_FILL: begin
                    l1_fill_en <= 1'b1;
                    fsm <= H_RESPOND;
                end

                // Responde para o testbench/CPU depois do fill
                H_RESPOND: begin
                    done <= 1'b1;
                    l2_hit <= saved_l2_hit;
                    mem_access <= saved_mem_access;
                    fsm <= H_IDLE;
                end

                default: begin
                    fsm <= H_IDLE;
                end

            endcase
        end
    end

endmodule