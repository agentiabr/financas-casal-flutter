/// Modelo de Item extraído de NFC-e (Cupom Fiscal Eletrônico)
/// Conforme requisito: estabelecimento, data, nome do produto, quantidade,
/// unidade (UN, KG, L etc.), valor unitário, valor total do item, descontos.
/// Código e número do item são omitidos.
class NfceItem {
  final String name;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final double discount;

  const NfceItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    this.discount = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'produto': name,
      'nome': name,
      'qtd': quantity,
      'unidade': unit,
      'preco': unitPrice,
      'precoUnitario': unitPrice,
      'total': totalPrice,
      'subtotal': totalPrice,
      'desconto': discount,
      'validated': true,
    };
  }

  factory NfceItem.fromJson(Map<String, dynamic> json) {
    return NfceItem(
      name: (json['produto'] ?? json['nome'] ?? 'Produto') as String,
      quantity: (json['qtd'] as num?)?.toDouble() ?? 1.0,
      unit: (json['unidade'] ?? 'UN') as String,
      unitPrice: (json['preco'] ?? json['precoUnitario'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total'] ?? json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['desconto'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() =>
      'NfceItem(name: $name, qtd: $quantity $unit, unitPrice: $unitPrice, total: $totalPrice, discount: $discount)';
}

/// Modelo da Nota Fiscal NFC-e completa extraída da SEFAZ
class NfceInvoice {
  final String storeName;
  final String date; // YYYY-MM-DD
  final double total;
  final double discount;
  final String? paymentMethod;
  final String? accessKey; // 44 dígitos
  final String? rawUrl;
  final List<NfceItem> items;
  final bool isFallback;
  final String? errorMessage;

  const NfceInvoice({
    required this.storeName,
    required this.date,
    required this.total,
    this.discount = 0.0,
    this.paymentMethod,
    this.accessKey,
    this.rawUrl,
    required this.items,
    this.isFallback = false,
    this.errorMessage,
  });

  /// Construtor de Fallback quando a SEFAZ está inacessível ou com CAPTCHA
  factory NfceInvoice.fallback({
    String? accessKey,
    String? rawUrl,
    String? errorMessage,
  }) {
    final now = DateTime.now().toIso8601String().split('T')[0];
    return NfceInvoice(
      storeName: 'NFC-e Pendente de Consulta',
      date: now,
      total: 0.0,
      discount: 0.0,
      paymentMethod: 'Cartão de Crédito',
      accessKey: accessKey,
      rawUrl: rawUrl,
      items: const [],
      isFallback: true,
      errorMessage: errorMessage ?? 'Não foi possível consultar a SEFAZ no momento. Chave de acesso preservada.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': !isFallback && (items.isNotEmpty || total > 0),
      'isFallback': isFallback,
      'store': storeName,
      'estabelecimento': storeName,
      'date': date,
      'data': date,
      'total': total,
      'valor_total': total,
      'discount': discount,
      'desconto': discount,
      'payment': paymentMethod ?? 'Cartão de Crédito',
      'items': items.map((e) => e.toJson()).toList(),
      'itens': items.map((e) => e.toJson()).toList(),
      'accessKey': accessKey,
      'chaveAcesso': accessKey,
      'rawUrl': rawUrl,
      'errorMessage': errorMessage,
    };
  }

  @override
  String toString() =>
      'NfceInvoice(store: $storeName, date: $date, total: $total, items: ${items.length}, isFallback: $isFallback)';
}
