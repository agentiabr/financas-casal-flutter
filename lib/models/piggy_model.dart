class PiggyModel {
  final int id;
  final String nome;
  final double meta;
  double saldoAtual;
  final String cor;
  final String icone;

  PiggyModel({
    required this.id,
    required this.nome,
    required this.meta,
    this.saldoAtual = 0.0,
    this.cor = 'blue',
    this.icone = 'piggy-bank',
  });

  double get percentual => meta > 0 ? (saldoAtual / meta).clamp(0.0, 1.0) : 0.0;

  factory PiggyModel.fromJson(Map<String, dynamic> json) {
    return PiggyModel(
      id: json['id'] as int? ?? 0,
      nome: json['nome'] ?? '',
      meta: (json['meta'] as num?)?.toDouble() ?? 0.0,
      saldoAtual: (json['saldo_atual'] as num?)?.toDouble() ?? 0.0,
      cor: json['cor'] ?? 'blue',
      icone: json['icone'] ?? 'piggy-bank',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'meta': meta,
      'saldo_atual': saldoAtual,
      'cor': cor,
      'icone': icone,
    };
  }
}
