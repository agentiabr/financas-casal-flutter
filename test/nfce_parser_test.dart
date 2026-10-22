import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:financas_casal_flutter/services/nfce/nfce.dart';

void main() {
  group('NfceNumberParser - Normalização de Números e Unidades', () {
    test('Converte valores monetários com vírgula e prefixos brasileiros', () {
      expect(NfceNumberParser.parseCurrency('0,15'), equals(0.15));
      expect(NfceNumberParser.parseCurrency('2,39'), equals(2.39));
      expect(NfceNumberParser.parseCurrency('5,29'), equals(5.29));
      expect(NfceNumberParser.parseCurrency('7,34'), equals(7.34));
      expect(NfceNumberParser.parseCurrency('20,09'), equals(20.09));
      expect(NfceNumberParser.parseCurrency('R$ 20,09'), equals(20.09));
      expect(NfceNumberParser.parseCurrency('Vl. Total: 1.250,50'), equals(1250.50));
      expect(NfceNumberParser.parseCurrency(''), equals(0.0));
      expect(NfceNumberParser.parseCurrency(null), equals(0.0));
    });

    test('Converte quantidades decimais (KG) e inteiras (UN)', () {
      expect(NfceNumberParser.parseQuantity('2'), equals(2.0));
      expect(NfceNumberParser.parseQuantity('1'), equals(1.0));
      expect(NfceNumberParser.parseQuantity('1,05'), equals(1.05));
      expect(NfceNumberParser.parseQuantity('0,19'), equals(0.19));
      expect(NfceNumberParser.parseQuantity('0,570'), equals(0.57));
      expect(NfceNumberParser.parseQuantity('Qtd.: 1,05'), equals(1.05));
      expect(NfceNumberParser.parseQuantity('Qtde: 0,570'), equals(0.57));
      expect(NfceNumberParser.parseQuantity(''), equals(1.0));
      expect(NfceNumberParser.parseQuantity(null), equals(1.0));
    });

    test('Normaliza unidades de medida da NFC-e', () {
      expect(NfceNumberParser.normalizeUnit('UN'), equals('UN'));
      expect(NfceNumberParser.normalizeUnit('un'), equals('UN'));
      expect(NfceNumberParser.normalizeUnit('UND'), equals('UN'));
      expect(NfceNumberParser.normalizeUnit('UN: UN'), equals('UN'));
      expect(NfceNumberParser.normalizeUnit('KG'), equals('KG'));
      expect(NfceNumberParser.normalizeUnit('kg'), equals('KG'));
      expect(NfceNumberParser.normalizeUnit('UN: KG'), equals('KG'));
      expect(NfceNumberParser.normalizeUnit('L'), equals('L'));
      expect(NfceNumberParser.normalizeUnit('LT'), equals('L'));
      expect(NfceNumberParser.normalizeUnit('CX'), equals('CX'));
      expect(NfceNumberParser.normalizeUnit('PCT'), equals('PCT'));
      expect(NfceNumberParser.normalizeUnit(null), equals('UN'));
    });

    test('Extrai Chave de Acesso de 44 dígitos da URL e do texto', () {
      const spUrl =
          'https://www.nfce.fazenda.sp.gov.br/qrcode?p=35261003476811000150650010000123451987654321|2|1|1|c89df';
      expect(
        NfceNumberParser.extractAccessKey(spUrl),
        equals('35261003476811000150650010000123451987654321'),
      );

      const spacedKey = '3526 1003 4768 1100 0150 6500 1000 0123 4519 8765 4321';
      expect(
        NfceNumberParser.extractAccessKey(spacedKey),
        equals('35261003476811000150650010000123451987654321'),
      );
    });

    test('Converte datas brasileiras para padrão ISO (YYYY-MM-DD)', () {
      expect(NfceNumberParser.parseDateToIso('22/10/2026 14:35:12'), equals('2026-10-22'));
      expect(NfceNumberParser.parseDateToIso('22/10/2026'), equals('2026-10-22'));
      expect(NfceNumberParser.parseDateToIso('2026-10-22'), equals('2026-10-22'));
    });
  });

  group('NfceParser - Layout SEFAZ SP (Exemplo Real Supermercado Dia)', () {
    late String spHtml;
    final parser = NfceParser();

    setUp(() {
      final file = File('test/fixtures/nfce_sp_dia.html');
      spHtml = file.readAsStringSync();
    });

    test('Extrai estabelecimento, data e total oficial pago com sucesso', () {
      final invoice = parser.parse(spHtml);

      expect(invoice.isFallback, isFalse);
      expect(invoice.storeName, contains('SUPERMERCADO DIA'));
      expect(invoice.date, equals('2026-10-22'));
      expect(invoice.total, equals(20.09));
      expect(invoice.discount, equals(1.30));
      expect(invoice.paymentMethod, equals('Cartão de Crédito'));
      expect(invoice.accessKey, equals('35261003476811000150650010000123451987654321'));
    });

    test('Extrai todos os 6 itens reais sem código/número, com KG e desconto', () {
      final invoice = parser.parse(spHtml);
      expect(invoice.items.length, equals(6));

      // 1. Sacola Verde 2 UN x 0,15 = 0,30
      final item1 = invoice.items[0];
      expect(item1.name, equals('Sacola Verde'));
      expect(item1.quantity, equals(2.0));
      expect(item1.unit, equals('UN'));
      expect(item1.unitPrice, equals(0.15));
      expect(item1.totalPrice, equals(0.30));
      expect(item1.discount, equals(0.0));

      // 2. Água Mineral c/ Gás Dia 1,5L 1 UN x 2,39 = 2,39
      final item2 = invoice.items[1];
      expect(item2.name, equals('Água Mineral c/ Gás Dia 1,5L'));
      expect(item2.quantity, equals(1.0));
      expect(item2.unit, equals('UN'));
      expect(item2.unitPrice, equals(2.39));
      expect(item2.totalPrice, equals(2.39));

      // 3. Lava Louças Dia 1L 1 UN x 5,29 com desconto 1,30 = 3,99
      final item3 = invoice.items[2];
      expect(item3.name, equals('Lava Louças Dia 1L'));
      expect(item3.quantity, equals(1.0));
      expect(item3.unit, equals('UN'));
      expect(item3.unitPrice, equals(5.29));
      expect(item3.discount, equals(1.30));
      expect(item3.totalPrice, equals(3.99));

      // 4. Mexerica Murcote 1,05 KG x 6,99 = 7,34
      final item4 = invoice.items[3];
      expect(item4.name, equals('Mexerica Murcote'));
      expect(item4.quantity, equals(1.05));
      expect(item4.unit, equals('KG'));
      expect(item4.unitPrice, equals(6.99));
      expect(item4.totalPrice, equals(7.34));

      // 5. Limão Taiti 0,19 KG x 10,99 = 2,09
      final item5 = invoice.items[4];
      expect(item5.name, equals('Limão Taiti'));
      expect(item5.quantity, equals(0.19));
      expect(item5.unit, equals('KG'));
      expect(item5.unitPrice, equals(10.99));
      expect(item5.totalPrice, equals(2.09));

      // 6. Banana Nanica 0,570 KG x 6,99 = 3,98
      final item6 = invoice.items[5];
      expect(item6.name, equals('Banana Nanica'));
      expect(item6.quantity, equals(0.57));
      expect(item6.unit, equals('KG'));
      expect(item6.unitPrice, equals(6.99));
      expect(item6.totalPrice, equals(3.98));

      // Verifica que a soma exata dos itens fecha em 20.09
      final sumItems = invoice.items.fold(0.0, (acc, it) => acc + it.totalPrice);
      expect(double.parse(sumItems.toStringAsFixed(2)), equals(20.09));
    });
  });

  group('NfceParser - Layout Nacional Padrão (SVRS / Portal Nacional)', () {
    late String nacionalHtml;
    final parser = NfceParser();

    setUp(() {
      final file = File('test/fixtures/nfce_nacional_padrao.html');
      nacionalHtml = file.readAsStringSync();
    });

    test('Extrai estabelecimento, data, itens e total no padrão nacional', () {
      final invoice = parser.parse(nacionalHtml);

      expect(invoice.isFallback, isFalse);
      expect(invoice.storeName, contains('HORTIFRUTI & MERCADO NATURAL'));
      expect(invoice.date, equals('2026-10-18'));
      expect(invoice.total, equals(60.80));
      expect(invoice.discount, equals(3.90));
      expect(invoice.paymentMethod, equals('PIX'));
      expect(invoice.accessKey, equals('43261012345678000190650010000543211098765432'));

      expect(invoice.items.length, equals(3));
      expect(invoice.items[0].name, equals('Maçã Gala Nacional'));
      expect(invoice.items[0].quantity, equals(1.25));
      expect(invoice.items[0].unit, equals('KG'));
      expect(invoice.items[0].totalPrice, equals(11.13));

      expect(invoice.items[1].name, equals('Leite Integral Desnatado 1L'));
      expect(invoice.items[1].quantity, equals(3.0));
      expect(invoice.items[1].unit, equals('UN'));
    });
  });

  group('NfceParser - Layout SEFAZ SP Oficial (ConsultaQRCode.aspx Joanin)', () {
    late String joaninHtml;
    final parser = NfceParser();

    setUp(() {
      final file = File('test/fixtures/nfce_sp_joanin.html');
      joaninHtml = file.readAsStringSync();
    });

    test('Extrai nome fantasia Supermercados Joanin, total de 15.87 e 6 itens reais', () {
      final invoice = parser.parse(joaninHtml);

      expect(invoice.isFallback, isFalse);
      expect(invoice.storeName, contains('Joanin'));
      expect(invoice.total, equals(15.87));
      expect(invoice.items.length, equals(6));

      // Item 1: Água Crystal
      expect(invoice.items[0].name, contains('AGUA MIN CRYSTAL'));
      expect(invoice.items[0].unitPrice, equals(4.45));
      expect(invoice.items[0].totalPrice, equals(4.45));

      // Item 2: Pão Francês (KG)
      expect(invoice.items[1].name, contains('PAO FRANCES'));
      expect(invoice.items[1].quantity, equals(0.312));
      expect(invoice.items[1].unit, equals('KG'));
      expect(invoice.items[1].totalPrice, equals(5.92));
    });
  });

  group('NfceParser - Tratamento de Falhas e Fallback', () {
    final parser = NfceParser();

    test('Retorna modelo de fallback quando HTML está corrompido ou vazio', () {
      const badUrl =
          'https://www.nfce.fazenda.sp.gov.br/qrcode?p=35261003476811000150650010000123451987654321|2|1|1|c89df';
      final invoice = parser.parse('<html><body>Erro no servidor</body></html>', rawUrl: badUrl);

      expect(invoice.isFallback, isTrue);
      expect(invoice.accessKey, equals('35261003476811000150650010000123451987654321'));
      expect(invoice.rawUrl, equals(badUrl));
      expect(invoice.errorMessage, isNotEmpty);
    });

    test('Gera JSON compatível com o contrato JS da WebView', () {
      final item = NfceItem(
        name: 'Sacola Verde',
        quantity: 2.0,
        unit: 'UN',
        unitPrice: 0.15,
        totalPrice: 0.30,
      );
      final invoice = NfceInvoice(
        storeName: 'Supermercado Dia',
        date: '2026-10-22',
        total: 0.30,
        items: [item],
        accessKey: '35261003476811000150650010000123451987654321',
      );

      final json = invoice.toJson();
      expect(json['success'], isTrue);
      expect(json['store'], equals('Supermercado Dia'));
      expect(json['total'], equals(0.30));
      expect(json['items'], isA<List>());
      expect(json['items'][0]['produto'], equals('Sacola Verde'));
      expect(json['items'][0]['qtd'], equals(2.0));
      expect(json['items'][0]['unidade'], equals('UN'));
    });
  });
}
