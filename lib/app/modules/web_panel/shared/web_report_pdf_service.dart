import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../data/providers/web_api_provider.dart';

class WebReportPdfService {
  static final NumberFormat _money = NumberFormat('#,##0.00', 'es');
  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');

  static Future<Uint8List> build({
    required WebApiProvider provider,
    required DateTime desde,
    required DateTime hasta,
    required String title,
  }) async {
    final query = <String, dynamic>{
      'desde': DateFormat('yyyy-MM-dd').format(desde),
      'hasta': DateFormat('yyyy-MM-dd').format(hasta),
    };

    final results = await Future.wait<List<dynamic>>([
      provider.getList('/reportes/efectividad-zona', query),
      provider.getList('/reportes/rendimiento-visitador', query),
      provider.getList('/reportes/efectividad-cliente', query),
    ]);

    final zones = _maps(results[0]);
    final visitadores = _maps(results[1]);
    final clients = _maps(results[2]);

    final totalVisits = visitadores.fold<int>(
      0,
      (sum, item) => sum + _int(item['visitas']),
    );
    final totalEffective = visitadores.fold<int>(
      0,
      (sum, item) => sum + _int(item['efectivas']),
    );
    final totalOrders = visitadores.fold<int>(
      0,
      (sum, item) => sum + _int(item['pedidos']),
    );
    final totalAmount = visitadores.fold<double>(
      0,
      (sum, item) => sum + _double(item['monto_total']),
    );
    final effectiveness = totalVisits <= 0
        ? 0.0
        : (totalEffective / totalVisits) * 100;

    final document = pw.Document(
      title: 'SIGPRED - $title',
      author: 'SIGPRED',
      subject: 'Reporte de visitas y ventas',
      creator: 'SIGPRED Flutter Web',
    );

    final primary = PdfColor.fromHex('#EF007B');
    final dark = PdfColor.fromHex('#172033');
    final muted = PdfColor.fromHex('#667085');
    final light = PdfColor.fromHex('#F7F8FC');
    final border = PdfColor.fromHex('#E5E7EB');

    pw.Widget metric(String label, String value) {
      return pw.Container(
        width: 125,
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: light,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: border, width: .6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                color: muted,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                color: dark,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget sectionTitle(String text, String subtitle) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 7),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              text,
              style: pw.TextStyle(
                color: dark,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(subtitle, style: pw.TextStyle(color: muted, fontSize: 8.5)),
          ],
        ),
      );
    }

    pw.Widget table({
      required List<String> headers,
      required List<List<String>> rows,
      required Map<int, pw.TableColumnWidth> widths,
    }) {
      if (rows.isEmpty) {
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: border),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Text(
            'No existen registros para el periodo seleccionado.',
            style: pw.TextStyle(color: muted, fontSize: 9),
          ),
        );
      }

      return pw.Table.fromTextArray(
        headers: headers,
        data: rows,
        border: pw.TableBorder.all(color: border, width: .5),
        headerDecoration: pw.BoxDecoration(color: light),
        headerStyle: pw.TextStyle(
          color: dark,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
        cellStyle: pw.TextStyle(color: dark, fontSize: 7.4),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        columnWidths: widths,
      );
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 30),
        maxPages: 100,
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: primary, width: 1.2),
            ),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 10,
                height: 26,
                decoration: pw.BoxDecoration(
                  color: primary,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
              ),
              pw.SizedBox(width: 9),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SIGPRED',
                      style: pw.TextStyle(
                        color: primary,
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        color: dark,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Text(
                '${_date.format(desde)} - ${_date.format(hasta)}',
                style: pw.TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generado ${_dateTime.format(DateTime.now())}',
              style: pw.TextStyle(color: muted, fontSize: 7.5),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(color: muted, fontSize: 7.5),
            ),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 10),
          pw.Text(
            'Resumen del periodo',
            style: pw.TextStyle(
              color: dark,
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              metric('Visitas', '$totalVisits'),
              metric('Efectivas', '$totalEffective'),
              metric('Efectividad', '${effectiveness.toStringAsFixed(2)}%'),
              metric('Pedidos', '$totalOrders'),
              metric('Monto pedidos', 'Bs ${_money.format(totalAmount)}'),
            ],
          ),
          sectionTitle(
            'Efectividad por zona',
            'Consolidado de visitas, efectividad, pedidos y monto de ventas.',
          ),
          table(
            headers: const [
              'Zona',
              'Visitas',
              'Efectivas',
              'Efectividad',
              'Pedidos',
              'Monto',
            ],
            rows: zones.map((item) {
              return [
                _text(item['zona_nombre'], 'Sin zona'),
                '${_int(item['visitas'])}',
                '${_int(item['efectivas'])}',
                '${_double(item['efectividad_porcentaje']).toStringAsFixed(2)}%',
                '${_int(item['pedidos'])}',
                'Bs ${_money.format(_double(item['monto_total']))}',
              ];
            }).toList(),
            widths: const {
              0: pw.FlexColumnWidth(2.3),
              1: pw.FlexColumnWidth(.8),
              2: pw.FlexColumnWidth(.9),
              3: pw.FlexColumnWidth(1.0),
              4: pw.FlexColumnWidth(.8),
              5: pw.FlexColumnWidth(1.3),
            },
          ),
          sectionTitle(
            'Rendimiento por Visitador Médico',
            'Resultados del personal de campo dentro del rango seleccionado.',
          ),
          table(
            headers: const [
              'Visitador',
              'Visitas',
              'Efectivas',
              'Efectividad',
              'Pedidos',
              'Monto',
            ],
            rows: visitadores.map((item) {
              return [
                _text(item['usu_nombre'], 'Visitador'),
                '${_int(item['visitas'])}',
                '${_int(item['efectivas'])}',
                '${_double(item['efectividad_porcentaje']).toStringAsFixed(2)}%',
                '${_int(item['pedidos'])}',
                'Bs ${_money.format(_double(item['monto_total']))}',
              ];
            }).toList(),
            widths: const {
              0: pw.FlexColumnWidth(2.6),
              1: pw.FlexColumnWidth(.8),
              2: pw.FlexColumnWidth(.9),
              3: pw.FlexColumnWidth(1.0),
              4: pw.FlexColumnWidth(.8),
              5: pw.FlexColumnWidth(1.3),
            },
          ),
          sectionTitle(
            'Resultados por punto de visita',
            'Detalle de resultados acumulados por cliente/punto de visita.',
          ),
          table(
            headers: const [
              'Punto de visita',
              'Zona',
              'Visitas',
              'Efectivas',
              'Efectividad',
              'Pedidos',
              'Monto',
            ],
            rows: clients.map((item) {
              return [
                _text(item['cliente_nombre'], 'Punto de visita'),
                _text(item['zona_nombre'], 'Sin zona'),
                '${_int(item['visitas'])}',
                '${_int(item['efectivas'])}',
                '${_double(item['efectividad_porcentaje']).toStringAsFixed(2)}%',
                '${_int(item['pedidos'])}',
                'Bs ${_money.format(_double(item['monto_total']))}',
              ];
            }).toList(),
            widths: const {
              0: pw.FlexColumnWidth(2.4),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(.7),
              3: pw.FlexColumnWidth(.8),
              4: pw.FlexColumnWidth(.9),
              5: pw.FlexColumnWidth(.7),
              6: pw.FlexColumnWidth(1.2),
            },
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(
              color: light,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Text(
              'Fuente: SIGPRED. Los resultados corresponden al alcance del usuario autenticado y al periodo seleccionado.',
              style: pw.TextStyle(color: muted, fontSize: 7.8),
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  static List<Map<String, dynamic>> _maps(List<dynamic> source) {
    return source
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  static String _text(dynamic value, [String fallback = '-']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
