// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_deel_suppression.dart';

const _tracerName = 'dartastic_otel_libs_deel';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class DeelResult {
  /// Creates a result.
  const DeelResult({
    this.itemCount,
    this.contractType,
    this.contractStatus,
    this.workerCountryCode,
    this.payrollProvider,
    this.invoiceStatus,
    this.amountMinor,
    this.currency,
    this.paymentMethod,
    this.requestId,
    this.statusCode,
  });

  /// Items returned.
  final int? itemCount;

  /// `pay_as_you_go_time_based` / `pay_as_you_go_tasks` /
  /// `milestones` / `fixed` / `employee` / `eor` — distinct pricing
  /// and onboarding flows.
  final String? contractType;

  /// `in_progress` / `waiting_for_employee_signature` / `cancelled` /
  /// `terminated`.
  final String? contractStatus;

  /// ISO 3166 — worker's country (drives compliance routing).
  final String? workerCountryCode;

  /// EOR-side payroll engine when applicable.
  final String? payrollProvider;

  /// `paid` / `pending` / `failed` / `cancelled`.
  final String? invoiceStatus;

  /// Amount in minor units (avoid float drift).
  final int? amountMinor;

  /// ISO 4217.
  final String? currency;

  /// `bank_transfer` / `paypal` / `wise` / `payoneer` / `coinbase` /
  /// `revolut` — Deel routes through many rails.
  final String? paymentMethod;

  /// `X-Deel-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class DeelCallResult<T> {
  /// Creates a call result.
  const DeelCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final DeelResult? result;
}

/// Wraps a Deel API call in a CLIENT span. [operation] is one of
/// `contracts.list`, `contracts.get`, `contracts.create`,
/// `contracts.terminate`, `people.list`, `people.get`,
/// `invoices.list`, `invoices.create`, `invoice_adjustments.create`,
/// `time_off.list`, `tasks.list`, `payments.list`,
/// `webhooks.create`, `eor.employees.list`.
Future<T> tracedDeel<T>({
  required String operation,
  required Future<DeelCallResult<T>> Function() invoke,
}) async {
  if (deelInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'deel',
    'rpc.method': operation,
    'deel.operation': operation,
  };

  final span = _tracer().startSpan(
    'deel $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTelAPI.attributeInt(
          'deel.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.contractType != null) {
        extras.add(OTelAPI.attributeString(
          'deel.contract.type',
          r.result!.contractType!,
        ));
      }
      if (r.result!.contractStatus != null) {
        extras.add(OTelAPI.attributeString(
          'deel.contract.status',
          r.result!.contractStatus!,
        ));
      }
      if (r.result!.workerCountryCode != null) {
        extras.add(OTelAPI.attributeString(
          'deel.worker.country_code',
          r.result!.workerCountryCode!,
        ));
      }
      if (r.result!.payrollProvider != null) {
        extras.add(OTelAPI.attributeString(
          'deel.payroll.provider',
          r.result!.payrollProvider!,
        ));
      }
      if (r.result!.invoiceStatus != null) {
        extras.add(OTelAPI.attributeString(
          'deel.invoice.status',
          r.result!.invoiceStatus!,
        ));
        if (r.result!.invoiceStatus == 'failed') {
          span.setStatus(
            SpanStatusCode.Error,
            'Deel invoice failed',
          );
        }
      }
      if (r.result!.amountMinor != null) {
        extras.add(OTelAPI.attributeInt(
          'deel.amount.minor',
          r.result!.amountMinor!,
        ));
      }
      if (r.result!.currency != null) {
        extras.add(OTelAPI.attributeString(
          'deel.currency',
          r.result!.currency!,
        ));
      }
      if (r.result!.paymentMethod != null) {
        extras.add(OTelAPI.attributeString(
          'deel.payment_method',
          r.result!.paymentMethod!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'deel.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Deel HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
