class PriceItemModel {
  final int id;
  final String produto;
  final String estabelecimento;
  final DateTime data;
  final double preco;
  final double? precoAnterior;

  PriceItemModel({
    required this.id,
    required this.produto,
    required this.estabelecimento,
    required this.data,
    required this.preco,
    this.precoAnterior,
  });

  bool get isMaisCaro => precoAnterior != null && preco > precoAnterior!;
  bool get isMaisBarato => precoAnterior != null && preco < precoAnterior!;

  factory PriceItemModel.fromJson(Map<String, dynamic> json) {
    return PriceItemModel(
      id: json['id'] as int? ?? 0,
      produto: json['produto'] ?? '',
      estabelecimento: json['estabelecimento'] ?? '',
      data: DateTime.tryParse(json['data'] ?? '') ?? DateTime.now(),
      preco: (json['preco'] as num?)?.toDouble() ?? 0.0,
      precoAnterior: (json['preco_anterior'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'produto': produto,
      'estabelecimento': estabelecimento,
      'data': data.toIso8601String().split('T')[0],
      'preco': preco,
      'preco_anterior': precoAnterior,
    };
  }
}
