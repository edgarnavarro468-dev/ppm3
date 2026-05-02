import 'package:flutter_test/flutter_test.dart';
import 'package:ppm_mobile/core/models/models.dart';
import 'package:ppm_mobile/core/utils/formatters.dart';

void main() {
  test('muestra CTA de primer gasto cuando no hay gastos', () {
    final result = buildGroupSummary(
      currentUserId: 1,
      expenses: const [],
      balances: null,
      fallbackNetBalance: 0,
    );

    expect(result.title, 'Agrega el primer gasto');
    expect(result.tone, SummaryTone.action);
  });

  test('muestra deuda prioritaria cuando el usuario debe pagar', () {
    final result = buildGroupSummary(
      currentUserId: 1,
      expenses: [
        AppExpense(
          id: 1,
          groupId: 10,
          description: 'Cena',
          amount: 600,
          payer: const AppUser(id: 2, username: 'ana', email: 'ana@test.com', displayName: 'Ana'),
          participants: const [],
          createdAt: null,
        ),
      ],
      balances: BalancePayload(
        entries: const [],
        settlements: [
          SettlementSuggestion(
            fromUser: const AppUser(id: 1, username: 'ed', email: 'ed@test.com', displayName: 'Ed'),
            toUser: const AppUser(id: 2, username: 'ana', email: 'ana@test.com', displayName: 'Ana'),
            amount: 120,
          ),
        ],
      ),
      fallbackNetBalance: -120,
    );

    expect(result.title, contains('Debes'));
    expect(result.tone, SummaryTone.negative);
  });
}
