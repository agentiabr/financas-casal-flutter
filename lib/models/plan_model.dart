enum PlanType { solteiro, casal, familia }

class SubscriptionPlanModel {
  final PlanType type;
  final String title;
  final String subtitle;
  final double basePrice;
  final int maxIncludedMembers;
  final double additionalMemberPrice;
  final List<String> features;
  final bool isPopular;

  SubscriptionPlanModel({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.basePrice,
    required this.maxIncludedMembers,
    this.additionalMemberPrice = 10.00,
    required this.features,
    this.isPopular = false,
  });

  double calculateTotalPrice(int additionalMembersCount) {
    if (type != PlanType.familia) return basePrice;
    final validAddons = additionalMembersCount.clamp(0, 5);
    return basePrice + (validAddons * additionalMemberPrice);
  }

  static List<SubscriptionPlanModel> get defaultPlans => [
    SubscriptionPlanModel(
      type: PlanType.solteiro,
      title: 'Solteiro',
      subtitle: 'Controle individual completo e independente',
      basePrice: 19.90,
      maxIncludedMembers: 1,
      features: [
        '1 Usuário ativo',
        'Lançamento por Voz Nativo com IA',
        'Leitor de Cupom Fiscal com Câmera e OCR',
        'Máscara automática de centavos',
        'Gráficos e Análise Visual de Gastos',
        'Comparador de Preços de Supermercado',
        'Backup na Nuvem e Modo Offline',
      ],
    ),
    SubscriptionPlanModel(
      type: PlanType.casal,
      title: 'Casal',
      subtitle: 'Sincronização em tempo real entre você e seu parceiro(a)',
      basePrice: 29.90,
      maxIncludedMembers: 2,
      isPopular: true,
      features: [
        '2 Usuários com sincronização instantânea',
        'Divisão de gastos: Rodrigo, Márcia e Casal',
        'Visão unificada das finanças familiares',
        'Lançamento por Voz e Foto para ambos',
        'Controle de faturas e compras parceladas',
        'Modo Privacidade individual (olhinho)',
        'Metas e Cofrinhos compartilhados',
      ],
    ),
    SubscriptionPlanModel(
      type: PlanType.familia,
      title: 'Família',
      subtitle: 'Casal + filhos, dependentes ou sócios (até 5 inclusões)',
      basePrice: 29.90,
      maxIncludedMembers: 2,
      additionalMemberPrice: 10.00,
      features: [
        'Base para 2 usuários principais (Casal)',
        '+ R$ 10,00 por membro extra (máx. 5 adicionais)',
        'Até 7 pessoas sincronizadas na mesma conta',
        'Permissões personalizadas por membro',
        'Histórico e relatórios consolidados da casa',
        'Suporte prioritário e comparador ilimitado',
      ],
    ),
  ];
}
