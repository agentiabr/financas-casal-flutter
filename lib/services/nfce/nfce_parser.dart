import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'models/nfce_invoice.dart';
import 'nfce_number_parser.dart';

/// Parser robusto de HTML dos portais de consulta pública de NFC-e
/// Suporta o layout da SEFAZ SP (nfce.fazenda.sp.gov.br) e o layout nacional padrão (SVRS / Portal Nacional)
class NfceParser {
  /// Executa o parsing do HTML recebido da SEFAZ
  NfceInvoice parse(String html, {String? rawUrl}) {
    if (html.trim().isEmpty) {
      return NfceInvoice.fallback(
        accessKey: NfceNumberParser.extractAccessKey(rawUrl),
        rawUrl: rawUrl,
        errorMessage: 'Página HTML vazia retornada pela SEFAZ.',
      );
    }

    final document = html_parser.parse(html);

    // Extrai a chave de acesso (do HTML ou da URL)
    final accessKey = _extractAccessKey(document, rawUrl);

    // 1. Extração do Estabelecimento
    final storeName = _extractStoreName(document);

    // 2. Extração da Data da Compra
    final date = _extractDate(document);

    // 3. Extração dos Itens (SP e Nacional)
    final items = _extractItems(document);

    // 4. Extração dos Totais e Descontos
    final totals = _extractTotals(document, items);

    // 5. Forma de pagamento
    final payment = _extractPaymentMethod(document);

    // Se não encontrou nenhum item nem total e a página aparenta ser erro/bloqueio
    if (items.isEmpty && totals.total == 0.0) {
      return NfceInvoice.fallback(
        accessKey: accessKey,
        rawUrl: rawUrl,
        errorMessage: 'A página da SEFAZ não continha dados legíveis do cupom fiscal.',
      );
    }

    return NfceInvoice(
      storeName: storeName,
      date: date,
      total: totals.total,
      discount: totals.discount,
      paymentMethod: payment,
      accessKey: accessKey,
      rawUrl: rawUrl,
      items: items,
      isFallback: false,
    );
  }

  /// Extrai o nome do estabelecimento (priorizando Nome Fantasia)
  String _extractStoreName(dom.Document doc) {
    // 0. Prioridade Máxima: Seletores explícitos de Nome Fantasia
    final fantasiaSelectors = [
      '.fantasia',
      '#lblNomeFantasia',
      '.nomeFantasia',
      '#nomeFantasia',
      '.txtFantasia',
      '#fantasia',
      '.subTitulo',
    ];
    for (final sel in fantasiaSelectors) {
      final el = doc.querySelector(sel);
      if (el != null && el.text.trim().isNotEmpty) {
        final name = _cleanStoreName(el.text);
        if (name.isNotEmpty && !name.toLowerCase().contains('danfe') && !name.toLowerCase().contains('cnpj')) {
          return name;
        }
      }
    }

    // 1. SEFAZ SP: Procura Nome Fantasia nos nós complementares de endereço/filial (.txtCenter .text)
    final textDivs = doc.querySelectorAll('.txtCenter .text, .conteudoTr .text, .text');
    for (final div in textDivs) {
      final t = div.text.trim();
      final parts = t.split(',');
      for (final part in parts) {
        final p = part.trim();
        final pUpper = p.toUpperCase();
        if (pUpper.contains('MERCADO') ||
            pUpper.contains('SUPERMERCADO') ||
            pUpper.contains('DROGARIA') ||
            pUpper.contains('FARMACIA') ||
            pUpper.contains('PADARIA') ||
            pUpper.contains('JOANIN') ||
            pUpper.contains('ASSAI') ||
            pUpper.contains('CARREFOUR') ||
            pUpper.contains('ATACADO')) {
          final cleaned = _cleanStoreName(p);
          if (cleaned.isNotEmpty && !cleaned.toLowerCase().contains('cnpj')) {
            return cleaned;
          }
        }
      }
    }

    // 1.1 SEFAZ SP: .txtTopo ou #u20 (Razão Social)
    final txtTopo = doc.querySelector('.txtTopo') ??
        doc.querySelector('#u20') ??
        doc.querySelector('.conteudoTr .txtTopo') ??
        doc.querySelector('#conteudo .txtCenter div');

    if (txtTopo != null && txtTopo.text.trim().isNotEmpty) {
      final name = _cleanStoreName(txtTopo.text);
      if (name.isNotEmpty && !name.toLowerCase().contains('danfe')) {
        return name;
      }
    }

    // 2. Layout Nacional / SVRS: .empresa, .nomeEmpresa, .estabelecimento, h3
    final altSelectors = [
      '.empresa',
      '.nomeEmpresa',
      '#empresa',
      '.estabelecimento',
      '.ui-title',
      'h3',
      'h4',
    ];
    for (final sel in altSelectors) {
      final el = doc.querySelector(sel);
      if (el != null && el.text.trim().isNotEmpty) {
        final name = _cleanStoreName(el.text);
        if (name.isNotEmpty && !name.toLowerCase().contains('danfe')) {
          return name;
        }
      }
    }

    // Heurística: primeiro nó de texto em #conteudo antes de CNPJ
    final conteudo = doc.querySelector('#conteudo');
    if (conteudo != null) {
      for (final line in conteudo.text.split('\n')) {
        final t = line.trim();
        if (t.isNotEmpty &&
            !t.toLowerCase().contains('cnpj') &&
            !t.toLowerCase().contains('danfe') &&
            !t.toLowerCase().contains('nfc-e') &&
            t.length >= 3 &&
            t.length <= 80) {
          return _cleanStoreName(t);
        }
      }
    }

    return 'Estabelecimento Comercial';
  }

  String _cleanStoreName(String raw) {
    if (raw.isEmpty) return 'Estabelecimento Comercial';
    String s = raw
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'CNPJ:?.*', caseSensitive: false), '')
        .trim();

    // Mapeamento de Razões Sociais clássicas brasileiras para seus Nomes Fantasia amigáveis
    final upper = s.toUpperCase();
    if (upper.contains('COMERCIAL OSWALDO CRUZ') || upper.contains('JOANIN')) return 'Supermercados Joanin';
    if (upper.contains('DIA BRASIL')) return 'Supermercado Dia';
    if (upper.contains('SENDAS DISTRIBUIDORA')) return 'Assaí Atacadista';
    if (upper.contains('COMPANHIA BRASILEIRA DE DISTRIBUI')) return 'Pão de Açúcar / Extra';
    if (upper.contains('CARREFOUR COMERCIO')) return 'Carrefour';
    if (upper.contains('ATACADAO S')) return 'Atacadão';
    if (upper.contains('RAIA DROGASIL')) return 'Droga Raia / Drogasil';
    if (upper.contains('DROGARIA SAO PAULO') || upper.contains('DPSP')) return 'Drogaria São Paulo';
    if (upper.contains('DROGARIAS PACHECO')) return 'Drogarias Pacheco';
    if (upper.contains('SONDA SUPERMERCADOS')) return 'Sonda Supermercados';
    if (upper.contains('ZAFFARI')) return 'Zaffari';
    if (upper.contains('SUPERMERCADOS BH')) return 'Supermercados BH';
    if (upper.contains('IRMAOS MUFFATO')) return 'Super Muffato';

    // Remoção de sufixos societários e filiais
    s = s.replaceAll(RegExp(r'\s*(?:SOCIEDADE\s+LIMITADA|LTDA\.?|S/?A\.?|S\.A\.|EIRELI|M\.?E\.?|EPP)\b.*$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*[-•]?\s*(?:LOJA|FILIAL|SUCURSAL)\s*[\d\w\s-]*$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    return s.isNotEmpty ? s : raw.trim();
  }

  /// Extrai data no formato YYYY-MM-DD
  String _extractDate(dom.Document doc) {
    // Procura elementos com classe ou texto de emissão
    final emissaoEl = doc.querySelector('#dataEmissao') ??
        doc.querySelector('.emissao') ??
        doc.querySelector('#infos');

    if (emissaoEl != null) {
      final text = emissaoEl.text;
      final match = RegExp(r'(\d{2}/\d{2}/\d{4})').firstMatch(text);
      if (match != null) {
        return NfceNumberParser.parseDateToIso(match.group(1));
      }
    }

    // Busca no corpo geral do documento por "Emissão: DD/MM/YYYY"
    final bodyText = doc.body?.text ?? '';
    final match = RegExp(r'emiss[ãa]o[:\s]+(\d{2}/\d{2}/\d{4})', caseSensitive: false).firstMatch(bodyText);
    if (match != null) {
      return NfceNumberParser.parseDateToIso(match.group(1));
    }

    final anyDateMatch = RegExp(r'\b(\d{2}/\d{2}/\d{4})\b').firstMatch(bodyText);
    if (anyDateMatch != null) {
      return NfceNumberParser.parseDateToIso(anyDateMatch.group(1));
    }

    return DateTime.now().toIso8601String().split('T')[0];
  }

  /// Extrai a lista de produtos (regras: código e número do item são omitidos)
  List<NfceItem> _extractItems(dom.Document doc) {
    final List<NfceItem> items = [];

    // 1. Tabela SEFAZ SP: #tabResult
    final tableSp = doc.querySelector('#tabResult');
    if (tableSp != null) {
      final rows = tableSp.querySelectorAll('tr');
      for (final row in rows) {
        final item = _parseItemRowSp(row);
        if (item != null) {
          items.add(item);
        }
      }
      if (items.isNotEmpty) return items;
    }

    // 2. Tabela Nacional / SVRS / Outras SEFAZ: #tabelaItens, table.tabelaNormal, etc.
    final genericTable = doc.querySelector('#tabelaItens') ??
        doc.querySelector('table.tabelaNormal') ??
        doc.querySelector('table.list-itens') ??
        doc.querySelector('table');

    if (genericTable != null) {
      final rows = genericTable.querySelectorAll('tr');
      for (final row in rows) {
        final item = _parseItemRowSp(row) ?? _parseItemRowColumns(row);
        if (item != null) {
          items.add(item);
        }
      }
      if (items.isNotEmpty) return items;
    }

    // 3. Layout de Acordeão mobile (.ui-collapsible ou divs de item)
    final accordions = doc.querySelectorAll('.ui-collapsible');
    if (accordions.isNotEmpty) {
      for (final acc in accordions) {
        final item = _parseItemAccordion(acc);
        if (item != null) {
          items.add(item);
        }
      }
    }

    return items;
  }

  /// Parser de linha no padrão SP (#tabResult com .txtTit, .Rqtd, .RUN, .RvlUnit, .valor)
  NfceItem? _parseItemRowSp(dom.Element row) {
    final titleEl = row.querySelector('.txtTit');
    if (titleEl == null) return null;

    // Clona o texto do título removendo possíveis tags de código (.RCod)
    var rawName = titleEl.text;
    final rCod = titleEl.querySelector('.RCod');
    if (rCod != null) {
      rawName = rawName.replaceAll(rCod.text, '');
    }
    // Remove códigos residuais entre parênteses: (Código: 1234)
    final cleanName = rawName
        .replaceAll(RegExp(r'\(C[óo]digo:?[^\)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    if (cleanName.isEmpty) return null;

    // Quantidade
    final qtdEl = row.querySelector('.Rqtd');
    final quantity = NfceNumberParser.parseQuantity(qtdEl?.text);

    // Unidade
    final unEl = row.querySelector('.RUN');
    final unit = NfceNumberParser.normalizeUnit(unEl?.text);

    // Valor Unitário
    final vlUnitEl = row.querySelector('.RvlUnit');
    final unitPrice = NfceNumberParser.parseCurrency(vlUnitEl?.text);

    // Desconto do item (se houver)
    final descEl = row.querySelector('.Rdesconto') ?? row.querySelector('.desconto');
    double discount = 0.0;
    if (descEl != null) {
      discount = NfceNumberParser.parseCurrency(descEl.text);
    } else {
      // Procura por texto "Desconto: R$ X,XX" dentro da linha
      final descMatch = RegExp(r'desconto[:\s]*R?\$?\s*([\d\.,]+)', caseSensitive: false).firstMatch(row.text);
      if (descMatch != null) {
        discount = NfceNumberParser.parseCurrency(descMatch.group(1));
      }
    }

    // Valor Total do item
    final valorEl = row.querySelector('.valor');
    var totalPrice = NfceNumberParser.parseCurrency(valorEl?.text);

    // Fallback de valor total se ausente ou zerado
    if (totalPrice <= 0.0 && unitPrice > 0.0) {
      totalPrice = (quantity * unitPrice) - discount;
      if (totalPrice < 0) totalPrice = 0.0;
    }

    return NfceItem(
      name: cleanName,
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      discount: discount,
    );
  }

  /// Parser de linha em formato de colunas de tabela (td 0: Nome, td 1: Qtd, td 2: Un, td 3: Vl.Unit, td 4: Total)
  NfceItem? _parseItemRowColumns(dom.Element row) {
    final cells = row.querySelectorAll('td');
    if (cells.length < 4) return null;

    // Ignora cabeçalhos
    final firstText = cells[0].text.trim().toLowerCase();
    if (firstText.contains('descri') || firstText.contains('produto') || firstText.contains('item')) {
      return null;
    }

    final name = cells[0].text.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (name.isEmpty) return null;

    final quantity = NfceNumberParser.parseQuantity(cells[1].text);
    final unit = NfceNumberParser.normalizeUnit(cells[2].text);
    final unitPrice = NfceNumberParser.parseCurrency(cells[3].text);
    final totalPrice = cells.length >= 5
        ? NfceNumberParser.parseCurrency(cells[4].text)
        : (quantity * unitPrice);

    return NfceItem(
      name: name,
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
    );
  }

  /// Parser de layout acordeão mobile
  NfceItem? _parseItemAccordion(dom.Element acc) {
    final titleEl = acc.querySelector('h3') ?? acc.querySelector('.ui-btn');
    if (titleEl == null) return null;

    final name = titleEl.text.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (name.isEmpty) return null;

    final bodyText = acc.text;
    final qtdMatch = RegExp(r'qtd[e\.]*[:\s]*([\d\.,]+)', caseSensitive: false).firstMatch(bodyText);
    final unMatch = RegExp(r'un[:\s]*([a-zA-Z]+)', caseSensitive: false).firstMatch(bodyText);
    final vlMatch = RegExp(r'vl\.?\s*unit[:\s]*R?\$?\s*([\d\.,]+)', caseSensitive: false).firstMatch(bodyText);
    final totMatch = RegExp(r'(total|valor)[:\s]*R?\$?\s*([\d\.,]+)', caseSensitive: false).firstMatch(bodyText);
    final descMatch = RegExp(r'desconto[:\s]*R?\$?\s*([\d\.,]+)', caseSensitive: false).firstMatch(bodyText);

    final quantity = NfceNumberParser.parseQuantity(qtdMatch?.group(1));
    final unit = NfceNumberParser.normalizeUnit(unMatch?.group(1));
    final unitPrice = NfceNumberParser.parseCurrency(vlMatch?.group(1));
    final discount = NfceNumberParser.parseCurrency(descMatch?.group(1));
    var totalPrice = NfceNumberParser.parseCurrency(totMatch?.group(2));

    if (totalPrice <= 0.0 && unitPrice > 0.0) {
      totalPrice = (quantity * unitPrice) - discount;
    }

    return NfceItem(
      name: name,
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      discount: discount,
    );
  }

  /// Extrai o Total da Nota e Descontos Globais
  _NfceTotals _extractTotals(dom.Document doc, List<NfceItem> items) {
    double total = 0.0;
    double discount = 0.0;

    // 1. Procura em #totalNota no padrão SP
    final totalNota = doc.querySelector('#totalNota');
    if (totalNota != null) {
      final linhas = totalNota.querySelectorAll('#linhaTotal, .linhaTotal, div');
      for (final l in linhas) {
        final text = l.text.toLowerCase();
        if (text.contains('valor a pagar') || text.contains('total a pagar')) {
          final numbEl = l.querySelector('.totalNumb') ?? l.querySelector('.txtMax');
          total = NfceNumberParser.parseCurrency(numbEl?.text ?? l.text);
        } else if (text.contains('desconto') && !text.contains('sem desconto')) {
          final numbEl = l.querySelector('.totalNumb');
          discount = NfceNumberParser.parseCurrency(numbEl?.text ?? l.text);
        } else if (total == 0.0 && text.contains('valor total r\$')) {
          final numbEl = l.querySelector('.totalNumb');
          total = NfceNumberParser.parseCurrency(numbEl?.text ?? l.text);
        }
      }

      // Se encontrou a classe .txtMax com o valor em destaque
      if (total == 0.0) {
        final txtMax = totalNota.querySelector('.txtMax');
        if (txtMax != null) {
          total = NfceNumberParser.parseCurrency(txtMax.text);
        }
      }
    }

    // O layout nacional pode apresentar os totais em .totais-nota, sem #totalNota.
    if (discount == 0.0) {
      final discountRows = doc.querySelectorAll(
        '.totais-nota .linha, #totalNota #linhaTotal, #totalNota .linhaTotal',
      );
      for (final row in discountRows) {
        final text = row.text.toLowerCase();
        if (text.contains('desconto') && !text.contains('sem desconto')) {
          final value = row.querySelector('.totalNumb');
          discount = NfceNumberParser.parseCurrency(value?.text ?? row.text);
          if (discount > 0.0) break;
        }
      }
    }

    // 2. Busca genérica por classes de destaque de total (.totalNumb.txtMax ou .txtMax)
    if (total == 0.0) {
      final txtMax = doc.querySelector('.totalNumb.txtMax') ?? doc.querySelector('.txtMax');
      if (txtMax != null) {
        total = NfceNumberParser.parseCurrency(txtMax.text);
      }
    }

    // 3. Busca por texto "Valor a pagar" no corpo inteiro
    if (total == 0.0) {
      final bodyText = doc.body?.text ?? '';
      final match = RegExp(r'valor\s+a\s+pagar\s*R?\$?[:\s]*([\d\.,]+)', caseSensitive: false).firstMatch(bodyText);
      if (match != null) {
        total = NfceNumberParser.parseCurrency(match.group(1));
      }
    }

    // 4. Fallback: soma dos totais dos itens
    if (total == 0.0 && items.isNotEmpty) {
      total = items.fold(0.0, (acc, it) => acc + it.totalPrice);
    }

    // Se o desconto não foi identificado no cabeçalho geral, soma os descontos dos itens
    if (discount == 0.0 && items.isNotEmpty) {
      discount = items.fold(0.0, (acc, it) => acc + it.discount);
    }

    return _NfceTotals(total: total, discount: discount);
  }

  /// Extrai a forma de pagamento (Cartão de Crédito, PIX, etc.)
  String _extractPaymentMethod(dom.Document doc) {
    final totalNota = doc.querySelector('#totalNota');
    if (totalNota != null) {
      for (final el in totalNota.querySelectorAll('#linhaTotal, div')) {
        if (el.text.toLowerCase().contains('forma de pagamento') ||
            el.text.toLowerCase().contains('pagamento')) {
          final numbEl = el.querySelector('.totalNumb');
          final raw = (numbEl?.text ?? el.text)
              .replaceAll(RegExp(r'forma\s+de\s+pagamento[:\s]*', caseSensitive: false), '')
              .trim();
          if (raw.isNotEmpty) return raw;
        }
      }
    }

    final bodyText = doc.body?.text.toLowerCase() ?? '';
    if (bodyText.contains('cartão de crédito') || bodyText.contains('cartao de credito')) {
      return 'Cartão de Crédito';
    }
    if (bodyText.contains('cartão de débito') || bodyText.contains('cartao de debito')) {
      return 'Cartão de Débito';
    }
    if (bodyText.contains('pix')) {
      return 'PIX';
    }
    if (bodyText.contains('dinheiro')) {
      return 'Dinheiro';
    }

    return 'Cartão de Crédito';
  }

  /// Extrai a chave de acesso de 44 dígitos
  String? _extractAccessKey(dom.Document doc, String? rawUrl) {
    // 1. Da URL original do QR Code
    final keyFromUrl = NfceNumberParser.extractAccessKey(rawUrl);
    if (keyFromUrl != null) return keyFromUrl;

    // 2. Do HTML (.chave, #chave, #linhaChave)
    final chaveEl = doc.querySelector('.chave') ??
        doc.querySelector('#chave') ??
        doc.querySelector('.chaveAcesso');
    if (chaveEl != null) {
      final key = NfceNumberParser.extractAccessKey(chaveEl.text);
      if (key != null) return key;
    }

    // 3. Procura 44 dígitos no texto todo
    return NfceNumberParser.extractAccessKey(doc.body?.text);
  }
}

class _NfceTotals {
  final double total;
  final double discount;
  const _NfceTotals({required this.total, required this.discount});
}
