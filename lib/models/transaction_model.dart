class TransactionModel {
  final int id;
  final DateTime data;
  final String ciclo;
  final String tipo; // 'Receita', 'Despesa Fixa', 'Despesa Variável'
  final String categoria;
  final String descricao;
  final double valor;
  final String responsavel; // 'Rodrigo', 'Márcia', 'Comum (Casal)'
  final String formaPagamento;
  final String origemComprovante;
  final String? cartaoNome;

  TransactionModel({
    required this.id,
    required this.data,
    required this.ciclo,
    required this.tipo,
    required this.categoria,
    required this.descricao,
    required this.valor,
    required this.responsavel,
    required this.formaPagamento,
    this.origemComprovante = 'com_nota',
    this.cartaoNome,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int? ?? 0,
      data: DateTime.tryParse(json['data'] ?? '') ?? DateTime.now(),
      ciclo: json['ciclo'] ?? '',
      tipo: json['tipo'] ?? 'Despesa Variável',
      categoria: json['categoria'] ?? 'Outros',
      descricao: json['descricao'] ?? '',
      valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
      responsavel: json['responsavel'] ?? 'Comum (Casal)',
      formaPagamento: json['forma_pagamento'] ?? 'PIX',
      origemComprovante: json['origem_comprovante'] ?? 'com_nota',
      cartaoNome: json['cartao_nome'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'data': data.toIso8601String().split('T')[0],
      'ciclo': ciclo,
      'tipo': tipo,
      'categoria': categoria,
      'descricao': descricao,
      'valor': valor,
      'responsavel': responsavel,
      'forma_pagamento': formaPagamento,
      'origem_comprovante': origemComprovante,
      if (cartaoNome != null) 'cartao_nome': cartaoNome,
    };
    if (id > 0) {
      map['id'] = id;
    }
    return map;
  }
}
