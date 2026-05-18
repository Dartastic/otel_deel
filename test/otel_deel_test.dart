// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_deel/otel_deel.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_deel-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('contract create records type + country', () async {
    await tracedDeel<String>(
      operation: 'contracts.create',
      invoke: () async => const DeelCallResult(
        value: 'ok',
        result: DeelResult(
          contractType: 'eor',
          contractStatus: 'in_progress',
          workerCountryCode: 'PT',
          payrollProvider: 'deel_eor',
          statusCode: 201,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('deel contracts.create')!);
    expect(a['deel.contract.type'], 'eor');
    expect(a['deel.worker.country_code'], 'PT');
    expect(a['deel.payroll.provider'], 'deel_eor');
  });

  test('failed invoice sets span error', () async {
    await tracedDeel<String>(
      operation: 'invoices.create',
      invoke: () async => const DeelCallResult(
        value: 'ok',
        result: DeelResult(
          invoiceStatus: 'failed',
          amountMinor: 350000,
          currency: 'USD',
          paymentMethod: 'wise',
        ),
      ),
    );
    expect(
      spans.findSpanByName('deel invoices.create')!.status,
      SpanStatusCode.Error,
    );
    final a = attrsOf(spans.findSpanByName('deel invoices.create')!);
    expect(a['deel.payment_method'], 'wise');
    expect(a['deel.amount.minor'], 350000);
  });

  test('suppression skips spans', () async {
    await runWithoutDeelInstrumentationAsync(() async {
      await tracedDeel<String>(
        operation: 'people.list',
        invoke: () async => const DeelCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('deel '), isEmpty);
  });
}
