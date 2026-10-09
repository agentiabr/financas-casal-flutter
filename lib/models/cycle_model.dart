class CycleModel {
  final String nome;
  final DateTime inicio;
  final DateTime fim;
  final double salarioPlanejado;
  final bool isAtivo;

  CycleModel({
    required this.nome,
    required this.inicio,
    required this.fim,
    this.salarioPlanejado = 5560.00,
    this.isAtivo = false,
  });

  int get diasRestantes {
    final today = DateTime.now();
    final diff = fim.difference(today).inDays;
    return diff > 0 ? diff : 0;
  }
}
