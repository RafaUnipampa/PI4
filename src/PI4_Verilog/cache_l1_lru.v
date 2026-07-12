`timescale 1ns/1ps

module cache_l1_lru #(
    parameter ADDR_WIDTH  = 16,
    parameter INDEX_BITS  = 3,
    parameter OFFSET_BITS = 2
)(
    input  wire clk,
    input  wire rst,

    // Requisição de acesso à L1
    input  wire req,
    input  wire [ADDR_WIDTH-1:0] addr,

    // Preenchimento da L1 vindo da L2
    input  wire fill_en,
    input  wire [ADDR_WIDTH-1:0] fill_addr,

    // Resultado do acesso
    output reg done,
    output reg hit,
    output reg miss
);

    localparam SETS     = (1 << INDEX_BITS);
    localparam TAG_BITS = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;

    // Bits de validade das duas vias
    reg valid0 [0:SETS-1];
    reg valid1 [0:SETS-1];

    // Tags das duas vias
    reg [TAG_BITS-1:0] tag0 [0:SETS-1];
    reg [TAG_BITS-1:0] tag1 [0:SETS-1];

    // LRU por conjunto:
    // lru = 0 -> próxima vítima é a via 0
    // lru = 1 -> próxima vítima é a via 1
    reg lru [0:SETS-1];

    // Separação do endereço da requisição
    wire [INDEX_BITS-1:0] req_set;
    wire [TAG_BITS-1:0]   req_tag;

    assign req_set = addr[OFFSET_BITS + INDEX_BITS - 1 : OFFSET_BITS];
    assign req_tag = addr[ADDR_WIDTH-1 : OFFSET_BITS + INDEX_BITS];

    // Separação do endereço de preenchimento
    wire [INDEX_BITS-1:0] fill_set;
    wire [TAG_BITS-1:0]   fill_tag;

    assign fill_set = fill_addr[OFFSET_BITS + INDEX_BITS - 1 : OFFSET_BITS];
    assign fill_tag = fill_addr[ADDR_WIDTH-1 : OFFSET_BITS + INDEX_BITS];

    // Verificação de hit para acesso normal
    wire hit0;
    wire hit1;

    assign hit0 = valid0[req_set] && (tag0[req_set] == req_tag);
    assign hit1 = valid1[req_set] && (tag1[req_set] == req_tag);

    // Verificação se o bloco que está vindo da L2 já existe na L1
    wire fill_hit0;
    wire fill_hit1;

    assign fill_hit0 = valid0[fill_set] && (tag0[fill_set] == fill_tag);
    assign fill_hit1 = valid1[fill_set] && (tag1[fill_set] == fill_tag);

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            done <= 1'b0;
            hit  <= 1'b0;
            miss <= 1'b0;

            for (i = 0; i < SETS; i = i + 1) begin
                valid0[i] <= 1'b0;
                valid1[i] <= 1'b0;

                tag0[i] <= {TAG_BITS{1'b0}};
                tag1[i] <= {TAG_BITS{1'b0}};

                lru[i] <= 1'b0;
            end

        end else begin
            // Saídas são pulsos de 1 ciclo
            done <= 1'b0;
            hit  <= 1'b0;
            miss <= 1'b0;

            // =====================================================
            // Preenchimento da L1
            // =====================================================
            // Isso acontece depois que a L2 responde.
            // A L1 guarda o bloco para que próximos acessos possam Isso acontece depois que a L2 responde.
            // A L1 guarda dar hit.
            if (fill_en) begin

                // Caso o bloco já esteja na via 0, apenas atualiza LRU
                if (fill_hit0) begin
                    lru[fill_set] <= 1'b1;
                end

                // Caso o bloco já esteja na via 1, apenas atualiza LRU
                else if (fill_hit1) begin
                    lru[fill_set] <= 1'b0;
                end

                // Se a via 0 estiver livre, preenche a via 0
                else if (!valid0[fill_set]) begin
                    valid0[fill_set] <= 1'b1;
                    tag0[fill_set]   <= fill_tag;

                    // Como a via 0 acabou de ser usada,
                    // a próxima vítima passa a ser a via 1
                    lru[fill_set] <= 1'b1;
                end

                // Se a via 1 estiver livre, preenche a via 1
                else if (!valid1[fill_set]) begin
                    valid1[fill_set] <= 1'b1;
                    tag1[fill_set]   <= fill_tag;

                    // Como a via 1 acabou de ser usada,
                    // a próxima vítima passa a ser a via 0
                    lru[fill_set] <= 1'b0;
                end

                // Se as duas vias estão ocupadas, usa LRU
                else if (lru[fill_set] == 1'b0) begin
                    // Substitui a via 0
                    tag0[fill_set] <= fill_tag;

                    // Agora a via 0 acabou de ser usada,
                    // então a próxima vítima será a via 1
                    lru[fill_set] <= 1'b1;
                end

                else begin
                    // Substitui a via 1
                    tag1[fill_set] <= fill_tag;

                    // Agora a via 1 acabou de ser usada,
                    // então a próxima vítima será a via 0
                    lru[fill_set] <= 1'b0;
                end
            end

            // =====================================================
            // Consulta da L1
            // =====================================================
            if (req) begin
                done <= 1'b1;

                if (hit0) begin
                    hit <= 1'b1;

                    // Via 0 foi usada agora.
                    // Logo, a próxima vítima deve ser a via 1.
                    lru[req_set] <= 1'b1;
                end

                else if (hit1) begin
                    hit <= 1'b1;

                    // Via 1 foi usada agora.
                    // Logo, a próxima vítima deve ser a via 0.
                    lru[req_set] <= 1'b0;
                end

                else begin
                    miss <= 1'b1;
                end
            end
        end
    end

endmodule