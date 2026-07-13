transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog  -work work +incdir+C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto\ Integrador\ IV/Q-Learning\ (1)/Q-Learning\ (1)/Q-Learning/software/rtl/src {C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto Integrador IV/Q-Learning (1)/Q-Learning (1)/Q-Learning/software/rtl/src/qlearning_top_8way.v}
vlog  -work work +incdir+C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto\ Integrador\ IV/Q-Learning\ (1)/Q-Learning\ (1)/Q-Learning/software/rtl/src {C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto Integrador IV/Q-Learning (1)/Q-Learning (1)/Q-Learning/software/rtl/src/qlearning_system_8way.v}
vlog  -work work +incdir+C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto\ Integrador\ IV/Q-Learning\ (1)/Q-Learning\ (1)/Q-Learning/software/rtl/src {C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto Integrador IV/Q-Learning (1)/Q-Learning (1)/Q-Learning/software/rtl/src/qlearning_datapath_8way.v}
vlog  -work work +incdir+C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto\ Integrador\ IV/Q-Learning\ (1)/Q-Learning\ (1)/Q-Learning/software/rtl/src {C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto Integrador IV/Q-Learning (1)/Q-Learning (1)/Q-Learning/software/rtl/src/q_table_8way.v}
vlog  -work work +incdir+C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto\ Integrador\ IV/Q-Learning\ (1)/Q-Learning\ (1)/Q-Learning/software/rtl/src {C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto Integrador IV/Q-Learning (1)/Q-Learning (1)/Q-Learning/software/rtl/src/cache_l2_ql_8way.v}
vlog  -work work +incdir+C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto\ Integrador\ IV/Q-Learning\ (1)/Q-Learning\ (1)/Q-Learning/software/rtl/src {C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto Integrador IV/Q-Learning (1)/Q-Learning (1)/Q-Learning/software/rtl/src/cache_l1_lru.v}
vlog  -work work +incdir+C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto\ Integrador\ IV/Q-Learning\ (1)/Q-Learning\ (1)/Q-Learning/software/rtl/src {C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto Integrador IV/Q-Learning (1)/Q-Learning (1)/Q-Learning/software/rtl/src/cache_hierarchy_synth_top.v}
vlog  -work work +incdir+C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto\ Integrador\ IV/Q-Learning\ (1)/Q-Learning\ (1)/Q-Learning/software/rtl/src {C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto Integrador IV/Q-Learning (1)/Q-Learning (1)/Q-Learning/software/rtl/src/cache_hierarchy_l1_lru_l2_ql.v}
vlog  -work work +incdir+C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto\ Integrador\ IV/Q-Learning\ (1)/Q-Learning\ (1)/Q-Learning/software/rtl/src {C:/Users/rafae/OneDrive/Documentos/Unipampa/Projeto Integrador IV/Q-Learning (1)/Q-Learning (1)/Q-Learning/software/rtl/src/qlearning_control.v}

