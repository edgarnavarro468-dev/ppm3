import "../models/models.dart";

String money(double amount) {
  final absolute = amount.abs().toStringAsFixed(2);
  final parts = absolute.split('.');
  final whole = parts.first;
  final decimal = parts.last;
  final buffer = StringBuffer();

  for (var i = 0; i < whole.length; i++) {
    final reverseIndex = whole.length - i;
    buffer.write(whole[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }

  return '\$${buffer.toString()}.$decimal';
}

String formatDate(DateTime? value) {
  if (value == null) {
    return 'Fecha no disponible';
  }
  final local = value.toLocal();
  final monthNames = <int, String>{
    1: 'ene',
    2: 'feb',
    3: 'mar',
    4: 'abr',
    5: 'may',
    6: 'jun',
    7: 'jul',
    8: 'ago',
    9: 'sep',
    10: 'oct',
    11: 'nov',
    12: 'dic',
  };
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${monthNames[local.month]} ${local.year} · $hour:$minute';
}

enum SummaryTone { action, positive, negative, neutral }

class GroupSummaryInfo {
  const GroupSummaryInfo({
    required this.title,
    required this.caption,
    required this.tone,
  });

  final String title;
  final String caption;
  final SummaryTone tone;
}

GroupSummaryInfo buildGroupSummary({
  required int currentUserId,
  required List<AppExpense> expenses,
  required BalancePayload? balances,
  required double fallbackNetBalance,
}) {
  if (expenses.isEmpty) {
    return const GroupSummaryInfo(
      title: 'Agrega el primer gasto',
      caption: 'Hazlo una vez y el grupo entiende en segundos quien pago y como se reparte.',
      tone: SummaryTone.action,
    );
  }

  final settlement = balances?.settlements.cast<SettlementSuggestion?>().firstWhere(
        (item) => item?.fromUser.id == currentUserId || item?.toUser.id == currentUserId,
        orElse: () => null,
      );

  if (settlement != null) {
    if (settlement.fromUser.id == currentUserId) {
      return GroupSummaryInfo(
        title: 'Debes ${money(settlement.amount)} a ${settlement.toUser.displayName}',
        caption: 'Abre Saldos para registrar el pago o marcar la deuda como saldada.',
        tone: SummaryTone.negative,
      );
    }
    return GroupSummaryInfo(
      title: '${settlement.fromUser.displayName} te debe ${money(settlement.amount)}',
      caption: 'Abre Saldos para cerrar esta cuenta en cuanto te paguen.',
      tone: SummaryTone.positive,
    );
  }

  final net = balances?.entries
          .cast<BalanceEntry?>()
          .firstWhere((entry) => entry?.user.id == currentUserId, orElse: () => null)
          ?.net ??
      fallbackNetBalance;

  if (net > 0) {
    return GroupSummaryInfo(
      title: 'Vas a favor por ${money(net)}',
      caption: 'Tu balance esta positivo. En Saldos puedes revisar el detalle completo.',
      tone: SummaryTone.positive,
    );
  }
  if (net < 0) {
    return GroupSummaryInfo(
      title: 'Vas debiendo ${money(net.abs())}',
      caption: 'Entra a Saldos para ver a quien le toca recibir el pago.',
      tone: SummaryTone.negative,
    );
  }
  return const GroupSummaryInfo(
    title: 'Estas balanceado',
    caption: 'No hay cuentas pendientes en este momento dentro de este grupo.',
    tone: SummaryTone.neutral,
  );
}
