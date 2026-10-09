class CreditCardModel {
  final int id;
  final String nome;
  final String titular;
  final String final4;
  final double limite;
  final String cor;

  CreditCardModel({
    required this.id,
    required this.nome,
    required this.titular,
    required this.final4,
    required this.limite,
    this.cor = 'purple',
  });

  factory CreditCardModel.fromJson(Map<String, dynamic> json) {
    return CreditCardModel(
      id: json['id'] as int? ?? 0,
      nome: json['nome'] ?? '',
      titular: json['titular'] ?? 'Comum',
      final4: json['final_4'] ?? '0000',
      limite: (json['limite'] as num?)?.toDouble() ?? 0.0,
      cor: json['cor'] ?? 'purple',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'titular': titular,
      'final_4': final4,
      'limite': limite,
      'cor': cor,
    };
  }
}
