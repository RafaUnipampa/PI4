# PI4 - Cache Inteligente com Q-Learning em Verilog

Este repositório contém o desenvolvimento do projeto da disciplina Projeto Integrador IV, cujo objetivo é implementar e avaliar uma política inteligente de substituição de blocos em cache utilizando Q-Learning tabelado.

A proposta consiste em uma hierarquia de cache simplificada em RTL, implementada em Verilog, composta por uma cache L1 com política LRU e uma cache L2 com política de substituição baseada em Q-Learning.

## Objetivo

Implementar, simular e sintetizar uma arquitetura de cache inteligente, avaliando:

- taxa de acerto da cache;
- comportamento em diferentes padrões de acesso;
- custo em hardware;
- uso de recursos da FPGA;
- frequência máxima obtida na síntese.

## Arquitetura Implementada

A arquitetura implementada possui:

| Nível | Capacidade | Bloco | Associatividade | Política |
|---|---:|---:|---:|---|
| L1 | 4 KB | 32 bytes | 2 vias | LRU |
| L2 | 32 KB | 64 bytes | 8 vias | Q-Learning |

A hierarquia segue o fluxo:

```text
Requisição de endereço
        ↓
L1 - LRU
        ↓ miss
L2 - Q-Learning
        ↓ miss
Memória principal fictícia
