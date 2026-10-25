// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_deel/otel_deel.dart';

/// Traces Deel calls with OpenTelemetry.
///
/// `otel_deel` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Deel call in
/// [tracedDeel]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'deel-example');

  // Wraps a Deel API call in a CLIENT span.
  final deelId = await tracedDeel<String>(
    operation: 'contracts.create',
    invoke: () async {
      // Make the Deel call here, then report what it returned.
      const id = 'deel_8f3a2c';
      return const DeelCallResult(
          value: id,
          result: DeelResult(
              itemCount: 3,
              contractType: 'pay_as_you_go_time_based',
              contractStatus: 'in_progress',
              workerCountryCode: 'example',
              payrollProvider: 'example',
              invoiceStatus: 'paid',
              amountMinor: 1999,
              currency: 'usd',
              paymentMethod: 'bank_transfer',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedDeel contracts.create returned $deelId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutDeelInstrumentationAsync.
  await runWithoutDeelInstrumentationAsync(
    () => tracedDeel<String>(
      operation: 'contracts.create',
      invoke: () async {
        const id = 'deel_8f3a2c';
        return const DeelCallResult(
            value: id,
            result: DeelResult(
                itemCount: 3,
                contractType: 'pay_as_you_go_time_based',
                contractStatus: 'in_progress',
                workerCountryCode: 'example',
                payrollProvider: 'example',
                invoiceStatus: 'paid',
                amountMinor: 1999,
                currency: 'usd',
                paymentMethod: 'bank_transfer',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
