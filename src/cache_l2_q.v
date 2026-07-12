`timescale 1ns/1ps

module cache_l2_ql #(
    parameter ADDR_WIDTH  = 16,
    parameter INDEX_BITS  = 3,
    parameter OFFSET_BITS = 2
)(
    input  wire clk,
    input  wire rst,

    // Requisicao vinda da hierarquia depois de miss na L1
    input  wire req,
    input  wire [ADDR_WIDTH-1:0] addr,

    // Resultado do acesso na L2
    output reg done,
    output reg hit,
    output reg miss,

    // Representa acesso a memoria principal ficticia
    output reg mem_access,

    // Sinais de debug do nucleo Q-Learning
    output reg  q_start_dbg,
    output wire q_done_dbg,
    output wire q_victim_way_dbg
);

    localparam SETS     = (1 << INDEX_BITS);
    localparam TAG_BITS = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;

    // ============================================================
    // Estruturas da cache L2 - 2 vias
    // ============================================================

    reg valid0 [0:SETS-1];
    reg valid1 [0:SETS-1];

    reg [TAG_BITS-1:0] tag0 [0:SETS-1];
    reg [TAG_BITS-1:0] tag1 [0:SETS-1];

    // Mantemos LRU auxiliar para atualizacao de uso,
    // embora a substituicao principal da L2 seja pelo Q-Learning
    reg lru [0:SETS-1];

    // Endereco registrado para manter estavel durante a FSM
    reg [ADDR_WIDTH-1:0] addr_reg;

    // Separacao do endereco em indice e tag
    wire [INDEX_BITS-1:0] set_idx;
    wire [TAG_BITS-1:0]   tag_in;

    assign set_idx = addr_reg[OFFSET_BITS + INDEX_BITS - 1 : OFFSET_BITS];
    assign tag_in  = addr_reg[ADDR_WIDTH-1 : OFFSET_BITS + INDEX_BITS];

    // Verificacao de hit nas duas vias
    wire hit0;
    wire hit1;

    assign hit0 = valid0[set_idx] && (tag0[set_idx] == tag_in);
    assign hit1 = valid1[set_idx] && (tag1[set_idx] == tag_in);

    // ============================================================
    // Sinais para o nucleo Q-Learning
    // ============================================================

    reg q_start;
    reg [9:0] q_state;

    wire q_busy;
    wire q_done;
    wire q_victim_way;

    // Guarda a vitima escolhida pelo Q-Learning
    reg q_victim_reg;

    assign q_done_dbg       = q_done;
    assign q_victim_way_dbg = q_victim_way;

    // Nucleo Q-Learning ja implementado no projeto
    qlearning_system qcore (
        .clk(clk),
        .rst(rst),
        .start(q_start),
        .state(q_state),

        // Nesta primeira integracao, chamamos o Q-Learning
        // apenas em miss com conjunto cheio, entao usamos recompensa de miss.
        .hit(1'b0),

        .victim_way(q_victim_way),
        .busy(q_busy),
        .done(q_done)
    );

    // ============================================================
    // FSM da L2
    // ============================================================

    localparam S_IDLE   = 3'd0;
    localparam S_LOOKUP = 3'd1;
    localparam S_QSTART = 3'd2;
    localparam S_QWAIT  = 3'd3;
    localparam S_FILL   = 3'd4;

    reg [2:0] fsm;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            fsm <= S_IDLE;

            done       <= 1'b0;
            hit        <= 1'b0;
            miss       <= 1'b0;
            mem_access <= 1'b0;

            q_start     <= 1'b0;
            q_start_dbg <= 1'b0;
            q_state     <= 10'd0;
            q_victim_reg <= 1'b0;

            addr_reg <= {ADDR_WIDTH{1'b0}};

            for (i = 0; i < SETS; i = i + 1) begin
                valid0[i] <= 1'b0;
                valid1[i] <= 1'b0;

                tag0[i] <= {TAG_BITS{1'b0}};
                tag1[i] <= {TAG_BITS{1'b0}};

                lru[i] <= 1'b0;
            end

        end else begin
            // Saidas em pulso de 1 ciclo
            done       <= 1'b0;
            hit        <= 1'b0;
            miss       <= 1'b0;
            mem_access <= 1'b0;

            q_start     <= 1'b0;
            q_start_dbg <= 1'b0;

            case (fsm)

                // ====================================================
                // Espera uma requisicao da hierarquia
                // ====================================================
                S_IDLE: begin
                    if (req) begin
                        addr_reg <= addr;
                        fsm <= S_LOOKUP;
                    end
                end

                // ====================================================
                // Verifica se o endereco esta na L2
                // ====================================================
                S_LOOKUP: begin

                    // Hit na via 0
                    if (hit0) begin
                        done <= 1'b1;
                        hit  <= 1'b1;

                        // Via 0 foi usada agora,
                        // entao a proxima vitima LRU seria a via 1
                        lru[set_idx] <= 1'b1;

                        fsm <= S_IDLE;
                    end

                    // Hit na via 1
                    else if (hit1) begin
                        done <= 1'b1;
                        hit  <= 1'b1;

                        // Via 1 foi usada agora,
                        // entao a proxima vitima LRU seria a via 0
                        lru[set_idx] <= 1'b0;

                        fsm <= S_IDLE;
                    end

                    // Miss, mas via 0 esta livre
                    else if (!valid0[set_idx]) begin
                        valid0[set_idx] <= 1'b1;
                        tag0[set_idx]   <= tag_in;

                        // Via 0 acabou de ser usada
                        lru[set_idx] <= 1'b1;

                        done       <= 1'b1;
                        miss       <= 1'b1;
                        mem_access <= 1'b1;

                        fsm <= S_IDLE;
                    end

                    // Miss, mas via 1 esta livre
                    else if (!valid1[set_idx]) begin
                        valid1[set_idx] <= 1'b1;
                        tag1[set_idx]   <= tag_in;

                        // Via 1 acabou de ser usada
                        lru[set_idx] <= 1'b0;

                        done       <= 1'b1;
                        miss       <= 1'b1;
                        mem_access <= 1'b1;

                        fsm <= S_IDLE;
                    end

                    // Miss e as duas vias estao ocupadas:
                    // chama o nucleo Q-Learning para escolher a vitima
                    else begin
                        // Estado de 10 bits para a Q-table:
                        // 3 bits do set + 7 bits reduzidos da tag
                        q_state <= {set_idx, tag_in[6:0]};

                        fsm <= S_QSTART;
                    end
                end

                // ====================================================
                // Pulso de start para o Q-Learning
                // ====================================================
                S_QSTART: begin
                    q_start     <= 1'b1;
                    q_start_dbg <= 1'b1;

                    fsm <= S_QWAIT;
                end

                // ====================================================
                // Espera o Q-Learning terminar
                // ====================================================
                S_QWAIT: begin
                    if (q_done) begin
                        // Captura a vitima escolhida pelo Q-Learning
                        q_victim_reg <= q_victim_way;

                        fsm <= S_FILL;
                    end
                end

                // ====================================================
                // Substitui a via escolhida pelo Q-Learning
                // ====================================================
                S_FILL: begin
                    if (q_victim_reg == 1'b0) begin
                        tag0[set_idx] <= tag_in;

                        // Via 0 acabou de ser usada
                        lru[set_idx] <= 1'b1;
                    end else begin
                        tag1[set_idx] <= tag_in;

                        // Via 1 acabou de ser usada
                        lru[set_idx] <= 1'b0;
                    end

                    done       <= 1'b1;
                    miss       <= 1'b1;
                    mem_access <= 1'b1;

                    fsm <= S_IDLE;
                end

                default: begin
                    fsm <= S_IDLE;
                end

            endcase
        end
    end

endmodule