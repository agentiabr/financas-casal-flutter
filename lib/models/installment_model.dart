class InstallmentModel {
  final int id;
  final String descricao;
  final double valorParcela;
  final int totalParcelas;
  final int parcelaAtual;
  final double valorTotal;
  final String cartao;
  final String cicloInicio;

  InstallmentModel({
    required this.id,
    required this.descricao,
    required this.valorParcela,
    required this.totalParcelas,
    this.parcelaAtual = 1,
    required this.valorTotal,
    this.cartao = 'Nubank Rodrigo',
    required this.cicloInicio,
  });

  factory InstallmentModel.fromJson(Map<String, dynamic> json) {
    return InstallmentModel(
      id: json['id'] as int? ?? 0,
      descricao: json['descricao'] ?? '',
      valorParcela: (json['valor_parcela'] as num?)?.toDouble() ?? 0.0,
      totalParcelas: json['total_parcelas'] as int? ?? 1,
      parcelaAtual: json['parcela_atual'] as int? ?? 1,
      valorTotal: (json['valor_total'] as num?)?.toDouble() ?? 0.0,
      cartao: json['cartao'] ?? 'Nubank Rodrigo',
      cicloInicio: json['ciclo_inicio'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'descricao': descricao,
      'valor_parcela': valorParcela,
      'total_parcelas': totalParcelas,
      'parcela_atual': parcelaAtual,
      'valor_total': valorTotal,
      'cartao': cartao,
      'ciclo_inicio': cicloInicio,
    };
  }
}
