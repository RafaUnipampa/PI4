`timescale 1ns/1ps

module q_table_8way #(
    parameter Q_WIDTH     = 32,
    parameter STATE_WIDTH = 10,
    parameter NUM_STATES  = 1024
)(
    input  wire clk,

    // Estado usado para leitura da Q-table
    input  wire [STATE_WIDTH-1:0] read_state,

    // Estado usado no write-back
    input  wire [STATE_WIDTH-1:0] write_state,

    // Valor novo calculado pelo datapath
    input  wire signed [Q_WIDTH-1:0] write_data,

    // Habilita escrita na Q-table
    input  wire write_en,

    // Via escolhida para atualizar: 0 a 7
    input  wire [2:0] write_way,

    // Valores Q lidos para as 8 vias
    output reg signed [Q_WIDTH-1:0] q0,
    output reg signed [Q_WIDTH-1:0] q1,
    output reg signed [Q_WIDTH-1:0] q2,
    output reg signed [Q_WIDTH-1:0] q3,
    output reg signed [Q_WIDTH-1:0] q4,
    output reg signed [Q_WIDTH-1:0] q5,
    output reg signed [Q_WIDTH-1:0] q6,
    output reg signed [Q_WIDTH-1:0] q7
);

    // ============================================================
    // Q-table com 8 memórias, uma para cada ação/via da L2
    // ============================================================
    //
    // q_way0[state] -> valor Q para escolher a via 0
    // q_way1[state] -> valor Q para escolher a via 1
    // ...
    // q_way7[state] -> valor Q para escolher a via 7
    //
    // O atributo ramstyle orienta o Quartus a usar blocos M10K.
    // ============================================================

    (* ramstyle = "M10K" *) reg signed [Q_WIDTH-1:0] q_way0 [0:NUM_STATES-1];
    (* ramstyle = "M10K" *) reg signed [Q_WIDTH-1:0] q_way1 [0:NUM_STATES-1];
    (* ramstyle = "M10K" *) reg signed [Q_WIDTH-1:0] q_way2 [0:NUM_STATES-1];
    (* ramstyle = "M10K" *) reg signed [Q_WIDTH-1:0] q_way3 [0:NUM_STATES-1];
    (* ramstyle = "M10K" *) reg signed [Q_WIDTH-1:0] q_way4 [0:NUM_STATES-1];
    (* ramstyle = "M10K" *) reg signed [Q_WIDTH-1:0] q_way5 [0:NUM_STATES-1];
    (* ramstyle = "M10K" *) reg signed [Q_WIDTH-1:0] q_way6 [0:NUM_STATES-1];
    (* ramstyle = "M10K" *) reg signed [Q_WIDTH-1:0] q_way7 [0:NUM_STATES-1];

    integer i;

    // Inicializa os valores Q com zero para simulação
    initial begin
        for (i = 0; i < NUM_STATES; i = i + 1) begin
            q_way0[i] = {Q_WIDTH{1'b0}};
            q_way1[i] = {Q_WIDTH{1'b0}};
            q_way2[i] = {Q_WIDTH{1'b0}};
            q_way3[i] = {Q_WIDTH{1'b0}};
            q_way4[i] = {Q_WIDTH{1'b0}};
            q_way5[i] = {Q_WIDTH{1'b0}};
            q_way6[i] = {Q_WIDTH{1'b0}};
            q_way7[i] = {Q_WIDTH{1'b0}};
        end
    end

    // ============================================================
    // Leitura e escrita síncronas
    // ============================================================
    //
    // Leitura:
    // q0..q7 só atualizam na borda de subida do clock.
    //
    // Escrita:
    // Apenas a via indicada por write_way recebe write_data.
    // ============================================================

    always @(posedge clk) begin

        // Leitura síncrona das 8 ações
        q0 <= q_way0[read_state];
        q1 <= q_way1[read_state];
        q2 <= q_way2[read_state];
        q3 <= q_way3[read_state];
        q4 <= q_way4[read_state];
        q5 <= q_way5[read_state];
        q6 <= q_way6[read_state];
        q7 <= q_way7[read_state];

        // Escrita síncrona em apenas uma via
        if (write_en) begin
            case (write_way)

                3'd0: begin
                    q_way0[write_state] <= write_data;
                end

                3'd1: begin
                    q_way1[write_state] <= write_data;
                end

                3'd2: begin
                    q_way2[write_state] <= write_data;
                end

                3'd3: begin
                    q_way3[write_state] <= write_data;
                end

                3'd4: begin
                    q_way4[write_state] <= write_data;
                end

                3'd5: begin
                    q_way5[write_state] <= write_data;
                end

                3'd6: begin
                    q_way6[write_state] <= write_data;
                end

                3'd7: begin
                    q_way7[write_state] <= write_data;
                end

                default: begin
                    q_way0[write_state] <= write_data;
                end

            endcase
        end
    end

endmodule