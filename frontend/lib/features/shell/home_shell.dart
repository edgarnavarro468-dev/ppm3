import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/formatters.dart';
import '../app/app.dart';
import '../app/app_state.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(_navIndex)),
        actions: [
          IconButton(
            tooltip: 'Crear grupo',
            onPressed:
                state.isBusy ? null : () => _showCreateGroupSheet(context),
            icon: const Icon(Icons.group_add_rounded),
          ),
          IconButton(
            tooltip: 'Recargar',
            onPressed: state.isBusy
                ? null
                : () => _runAction(context, state.bootstrap),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.isBusy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: IndexedStack(
                index: _navIndex,
                children: [
                  _HomeTab(
                    section: _GroupSection.balances,
                    onOpenExpense: () => _showExpenseSheet(context),
                    onOpenCreateGroup: () => _showCreateGroupSheet(context),
                    onOpenInviteMember: () => _showInviteMemberSheet(context),
                    onDeleteGroup: () => _confirmDeleteGroup(context),
                    onOpenSettlement: () => _showSettlementSheet(context),
                    onOpenProposal: () => _showProposalSheet(context),
                    onOpenRating: () => _showRatingSheet(context),
                  ),
                  _HomeTab(
                    section: _GroupSection.expenses,
                    onOpenExpense: () => _showExpenseSheet(context),
                    onOpenCreateGroup: () => _showCreateGroupSheet(context),
                    onOpenInviteMember: () => _showInviteMemberSheet(context),
                    onDeleteGroup: () => _confirmDeleteGroup(context),
                    onOpenSettlement: () => _showSettlementSheet(context),
                    onOpenProposal: () => _showProposalSheet(context),
                    onOpenRating: () => _showRatingSheet(context),
                  ),
                  _HomeTab(
                    section: _GroupSection.proposals,
                    onOpenExpense: () => _showExpenseSheet(context),
                    onOpenCreateGroup: () => _showCreateGroupSheet(context),
                    onOpenInviteMember: () => _showInviteMemberSheet(context),
                    onDeleteGroup: () => _confirmDeleteGroup(context),
                    onOpenSettlement: () => _showSettlementSheet(context),
                    onOpenProposal: () => _showProposalSheet(context),
                    onOpenRating: () => _showRatingSheet(context),
                  ),
                  _HomeTab(
                    section: _GroupSection.community,
                    onOpenExpense: () => _showExpenseSheet(context),
                    onOpenCreateGroup: () => _showCreateGroupSheet(context),
                    onOpenInviteMember: () => _showInviteMemberSheet(context),
                    onDeleteGroup: () => _confirmDeleteGroup(context),
                    onOpenSettlement: () => _showSettlementSheet(context),
                    onOpenProposal: () => _showProposalSheet(context),
                    onOpenRating: () => _showRatingSheet(context),
                  ),
                  const _AccountTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _navIndex == 1 && state.activeGroup != null
          ? FloatingActionButton.extended(
              onPressed: state.isBusy ? null : () => _showExpenseSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar gasto'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (value) => setState(() => _navIndex = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Inicio'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Gastos',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline_rounded),
            selectedIcon: Icon(Icons.lightbulb_rounded),
            label: 'Propuestas',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Comunidad',
          ),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Cuenta'),
        ],
      ),
    );
  }

  String _titleForIndex(int value) {
    switch (value) {
      case 1:
        return 'Gastos';
      case 2:
        return 'Propuestas';
      case 3:
        return 'Comunidad';
      case 4:
        return 'Cuenta';
      default:
        return 'Saldos';
    }
  }

  Future<void> _showExpenseSheet(BuildContext context) async {
    final state = AppScope.of(context);
    final activeGroup = state.activeGroup;
    if (activeGroup == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ExpenseComposerSheet(
        group: activeGroup,
        currentUserId: state.currentUser?.id,
      ),
    );
  }

  Future<void> _showCreateGroupSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CreateGroupSheet(),
    );
  }

  Future<void> _showInviteMemberSheet(BuildContext context) async {
    final state = AppScope.of(context);
    final activeGroup = state.activeGroup;
    if (activeGroup == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _InviteMemberSheet(group: activeGroup),
    );
  }

  Future<void> _confirmDeleteGroup(BuildContext context) async {
    final state = AppScope.of(context);
    final group = state.activeGroup;
    if (group == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text(
          'Se registrara tu voto para eliminar "${group.name}". Si se alcanza la mayoria, el grupo se elimina.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Votar eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _runAction(context, () => state.voteDeleteActiveGroup());
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voto registrado para eliminar el grupo.')),
    );
  }

  Future<void> _showSettlementSheet(BuildContext context) async {
    final state = AppScope.of(context);
    final activeGroup = state.activeGroup;
    if (activeGroup == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SettlementSheet(
        group: activeGroup,
        currentUserId: state.currentUser?.id,
      ),
    );
  }

  Future<void> _showProposalSheet(BuildContext context) async {
    final state = AppScope.of(context);
    final activeGroup = state.activeGroup;
    if (activeGroup == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProposalSheet(
        group: activeGroup,
        currentUserId: state.currentUser?.id,
      ),
    );
  }

  Future<void> _showRatingSheet(BuildContext context) async {
    final state = AppScope.of(context);
    final activeGroup = state.activeGroup;
    if (activeGroup == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RatingSheet(
        group: activeGroup,
        currentUserId: state.currentUser?.id,
      ),
    );
  }
}

enum _GroupSection { balances, expenses, proposals, community }

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.section,
    required this.onOpenExpense,
    required this.onOpenCreateGroup,
    required this.onOpenInviteMember,
    required this.onDeleteGroup,
    required this.onOpenSettlement,
    required this.onOpenProposal,
    required this.onOpenRating,
  });

  final _GroupSection section;
  final VoidCallback onOpenExpense;
  final VoidCallback onOpenCreateGroup;
  final VoidCallback onOpenInviteMember;
  final VoidCallback onDeleteGroup;
  final VoidCallback onOpenSettlement;
  final VoidCallback onOpenProposal;
  final VoidCallback onOpenRating;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: state.bootstrap,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          Text(
            'Hola, ${state.currentUser?.displayName ?? 'amigo'}',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _introTextForSection(section),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          if (state.groups.isEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sin grupos todavia',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'Crea uno para empezar a probar el flujo movil completo: grupo, gasto, saldo y seguimiento.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onOpenCreateGroup,
                      icon: const Icon(Icons.group_add_rounded),
                      label: const Text('Crear primer grupo'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.groups.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final group = state.groups[index];
                        final selected = group.id == state.activeGroupId;
                        return ChoiceChip(
                          label: Text(group.name),
                          selected: selected,
                          onSelected: (_) => _runAction(
                              context, () => state.selectGroup(group.id)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Agregar grupo',
                    onPressed: onOpenCreateGroup,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (state.activeGroup != null) ...[
              _GroupHeroCard(
                onOpenExpense: onOpenExpense,
                onOpenBalances: onOpenSettlement,
                onOpenInviteMember: onOpenInviteMember,
                onDeleteGroup: onDeleteGroup,
              ),
              const SizedBox(height: 14),
              _MemberPreview(
                members: state.activeGroup!.members,
                onOpenInviteMember: onOpenInviteMember,
              ),
              const SizedBox(height: 14),
              if (section == _GroupSection.balances)
                _BalancesSection(onOpenSettlement: onOpenSettlement)
              else if (section == _GroupSection.expenses)
                _ExpensesSection(onOpenExpense: onOpenExpense)
              else if (section == _GroupSection.proposals)
                _ProposalsSection(onOpenProposal: onOpenProposal)
              else
                _CommunitySection(onOpenRating: onOpenRating),
            ],
          ],
        ],
      ),
    );
  }
}

String _introTextForSection(_GroupSection section) {
  switch (section) {
    case _GroupSection.expenses:
      return 'Registra gastos y revisa cada movimiento del grupo activo.';
    case _GroupSection.proposals:
      return 'Propongan planes, voten y elijan que sigue para el grupo.';
    case _GroupSection.community:
      return 'Roles, calificaciones y actividad social del grupo.';
    case _GroupSection.balances:
      return 'Inicio muestra primero saldos, deudas y liquidaciones.';
  }
}

class _GroupHeroCard extends StatelessWidget {
  const _GroupHeroCard({
    required this.onOpenExpense,
    required this.onOpenBalances,
    required this.onOpenInviteMember,
    required this.onDeleteGroup,
  });

  final VoidCallback onOpenExpense;
  final VoidCallback onOpenBalances;
  final VoidCallback onOpenInviteMember;
  final VoidCallback onDeleteGroup;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final group = state.activeGroup!;
    final summary = buildGroupSummary(
      currentUserId: state.currentUser!.id,
      expenses: state.expenses,
      balances: state.balances,
      fallbackNetBalance: group.myNetBalance,
    );
    final colors = _summaryPalette(summary.tone, Theme.of(context));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              group.description.isEmpty
                  ? 'Sin descripcion. Todo listo para probar el flujo movil.'
                  : group.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: colors.background,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(summary.caption),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpenExpense,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Agregar gasto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenBalances,
                    icon: const Icon(Icons.balance_rounded),
                    label: const Text('Ver saldos'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenInviteMember,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Invitar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDeleteGroup,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Eliminar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberPreview extends StatelessWidget {
  const _MemberPreview({
    required this.members,
    required this.onOpenInviteMember,
  });

  final List<AppUser> members;
  final VoidCallback onOpenInviteMember;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Miembros',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Invitar usuario',
                  onPressed: onOpenInviteMember,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: members
                  .map(
                    (user) => Chip(
                      avatar: CircleAvatar(
                          child: Text(_initials(user.displayName))),
                      label: Text('${user.displayName} - ${_roleLabel(user)}'),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpensesSection extends StatelessWidget {
  const _ExpensesSection({required this.onOpenExpense});

  final VoidCallback onOpenExpense;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.expenses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text('Aun no hay gastos. Agrega uno para empezar a dividir.',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '1. Agrega un gasto  2. Se divide automaticamente  3. Revisa quien debe a quien',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: onOpenExpense,
                  child: const Text('Agregar primer gasto')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: state.expenses
          .map(
            (expense) => Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(expense.description),
                subtitle: Text(
                  '${_expenseHeadline(state, expense)}\n${formatDate(expense.createdAt)}',
                ),
                isThreeLine: true,
                trailing: Text(
                  money(expense.amount),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _BalancesSection extends StatelessWidget {
  const _BalancesSection({required this.onOpenSettlement});

  final VoidCallback onOpenSettlement;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final balances = state.balances;
    if (balances == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Resumen de saldos',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onOpenSettlement,
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Liquidar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...balances.entries.map(
          (entry) => Card(
            child: ListTile(
              title: Text(entry.user.displayName),
              subtitle:
                  Text('Pago ${money(entry.paid)} · Debe ${money(entry.owed)}'),
              trailing: Text(
                entry.net == 0
                    ? 'Parejo'
                    : (entry.net > 0
                        ? '+${money(entry.net)}'
                        : '-${money(entry.net.abs())}'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: entry.net >= 0
                          ? const Color(0xFF1F7A4D)
                          : const Color(0xFFB63F2E),
                    ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sugerencias para saldar',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (balances.settlements.isEmpty)
          const Card(
            child: ListTile(
              title: Text('Todo va al corriente'),
              subtitle: Text('No hay deudas sugeridas por saldar.'),
            ),
          )
        else
          ...balances.settlements.map(
            (item) => Card(
              child: ListTile(
                title: Text(
                    '${item.fromUser.displayName} debe pagar a ${item.toUser.displayName}'),
                subtitle: state.currentUser?.id == item.fromUser.id
                    ? const Text('Puedes marcar esta deuda como saldada.')
                    : null,
                trailing: state.currentUser?.id == item.fromUser.id
                    ? FilledButton(
                        onPressed: state.isBusy
                            ? null
                            : () => _runAction(
                                  context,
                                  () => state.createSettlement(
                                    groupId: state.activeGroup!.id,
                                    fromUserId: item.fromUser.id,
                                    toUserId: item.toUser.id,
                                    amount: item.amount,
                                    notes: 'Liquidacion marcada desde saldos',
                                  ),
                                ),
                        child: Text(money(item.amount)),
                      )
                    : Text(
                        money(item.amount),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Historial de liquidaciones',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (state.settlements.isEmpty)
          const Card(
            child: ListTile(
              title: Text('Sin historial'),
              subtitle: Text('Todavia no hay liquidaciones registradas.'),
            ),
          )
        else
          ...state.settlements.map(
            (item) => Card(
              child: ListTile(
                title: Text(
                    '${item.fromUser.displayName} pago a ${item.toUser.displayName}'),
                subtitle: Text(
                  '${money(item.amount)} · ${item.notes.trim().isEmpty ? 'Sin notas' : item.notes}\n${item.receivedConfirmed ? 'Pago recibido confirmado' : 'Pendiente por confirmar'}',
                ),
                isThreeLine: true,
                trailing: _canConfirmSettlement(state.currentUser?.id, item)
                    ? OutlinedButton(
                        onPressed: state.isBusy
                            ? null
                            : () => _runAction(context,
                                () => state.confirmSettlement(item.id)),
                        child: const Text('Confirmar'),
                      )
                    : Text(
                        formatDate(item.createdAt),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProposalsSection extends StatelessWidget {
  const _ProposalsSection({required this.onOpenProposal});

  final VoidCallback onOpenProposal;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final currentUserId = state.currentUser?.id;
    final activeGroup = state.activeGroup;
    final isHost =
        activeGroup != null && currentUserId == activeGroup.createdBy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Propuestas del grupo',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onOpenProposal,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Proponer'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.proposals.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aun no hay propuestas',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Agrega comida, actividad o lugar para que el grupo vote desde la app.'),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: onOpenProposal,
                    child: const Text('Crear primera propuesta'),
                  ),
                ],
              ),
            ),
          )
        else
          ...state.proposals.map((proposal) {
            final alreadyVoted = currentUserId != null &&
                proposal.voters.any((user) => user.id == currentUserId);
            final canVote = proposal.status != 'selected' && !alreadyVoted;
            final canSelect = isHost && proposal.status != 'selected';

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            proposal.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (proposal.status == 'selected')
                          const Chip(label: Text('Elegida'))
                        else
                          Chip(label: Text(proposal.activityType)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (proposal.details.trim().isNotEmpty)
                      Text(proposal.details),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniInfo(
                            label: 'Total', value: money(proposal.totalAmount)),
                        _MiniInfo(
                            label: 'Votos',
                            value:
                                '${proposal.voteCount}/${proposal.voteThreshold}'),
                        if (proposal.providerName.trim().isNotEmpty)
                          _MiniInfo(
                              label: 'Proveedor', value: proposal.providerName),
                      ],
                    ),
                    if (proposal.paymentMethod.trim().isNotEmpty ||
                        proposal.scheduledForDate.trim().isNotEmpty ||
                        proposal.voteDeadline.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        [
                          if (proposal.paymentMethod.trim().isNotEmpty)
                            'Pago: ${proposal.paymentMethod}',
                          if (proposal.scheduledForDate.trim().isNotEmpty)
                            'Fecha: ${proposal.scheduledForDate}',
                          if (proposal.voteDeadline.trim().isNotEmpty)
                            'Cierre: ${proposal.voteDeadline}',
                        ].join('  ·  '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            proposal.creator.displayName,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ),
                        if (canVote)
                          FilledButton(
                            onPressed: state.isBusy
                                ? null
                                : () => _runAction(context,
                                    () => state.voteProposal(proposal.id)),
                            child: const Text('Votar'),
                          )
                        else if (alreadyVoted && proposal.status != 'selected')
                          const Chip(label: Text('Ya votaste')),
                        if (canSelect) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: state.isBusy
                                ? null
                                : () => _runAction(context,
                                    () => state.selectProposal(proposal.id)),
                            child: const Text('Elegir'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _CommunitySection extends StatelessWidget {
  const _CommunitySection({required this.onOpenRating});

  final VoidCallback onOpenRating;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final stats = state.stats;
    final ratings = state.ratings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Comunidad y metricas',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onOpenRating,
              icon: const Icon(Icons.star_outline_rounded),
              label: const Text('Calificar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (stats != null) ...[
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                      label: 'Gastos', value: '${stats.expenseCount}')),
              const SizedBox(width: 10),
              Expanded(
                  child: _StatCard(
                      label: 'Propuestas', value: '${stats.proposalCount}')),
              const SizedBox(width: 10),
              Expanded(
                  child: _StatCard(
                      label: 'Liquidaciones',
                      value: '${stats.settlementCount}')),
            ],
          ),
          if (stats.selectedProposal != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Propuesta elegida'),
                subtitle: Text(
                    '${stats.selectedProposal!.title} · ${stats.selectedProposal!.activityType}'),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
        Text(
          'Ranking del grupo',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (ratings == null || ratings.leaderboard.isEmpty)
          const Card(
            child: ListTile(
              title: Text('Sin calificaciones todavia'),
              subtitle: Text(
                  'Cuando empiecen a calificarse, apareceran aqui los mejores perfiles del grupo.'),
            ),
          )
        else
          ...ratings.leaderboard.take(5).map(
                (entry) => Card(
                  child: ListTile(
                    title: Text(entry.user.displayName),
                    subtitle: Text(
                        '${entry.badgeTitle} · ${entry.ratingCount} reseñas'),
                    trailing: Text(entry.averageScore.toStringAsFixed(1)),
                  ),
                ),
              ),
        if (stats != null && stats.spendByUser.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Quien ha pagado mas',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...stats.spendByUser.take(5).map(
                (row) => Card(
                  child: ListTile(
                    title: Text(row.label),
                    trailing: Text(
                      money(row.amount),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
        ],
        if (ratings != null && ratings.ratings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Reseñas recientes',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...ratings.ratings.take(5).map(
                (item) => Card(
                  child: ListTile(
                    title:
                        Text('${item.ratedUser.displayName} · ${item.score}/5'),
                    subtitle: Text(
                        '${item.title}\n${item.comment.trim().isEmpty ? 'Sin comentario' : item.comment}'),
                    isThreeLine: true,
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.5),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _AccountTab extends StatefulWidget {
  const _AccountTab();

  @override
  State<_AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<_AccountTab> {
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  int? _syncedUserId;

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    if (_syncedUserId != user.id) {
      _syncControllers(user);
    }

    final previewName = _previewDisplayName(user);
    final previewAvatarUrl = _avatarUrlController.text.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _ProfileAvatar(
                  imageUrl: previewAvatarUrl,
                  fallbackLabel: _initials(previewName),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(previewName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(user.email),
                      const SizedBox(height: 4),
                      SelectableText(
                        'Codigo: ${user.publicCode}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _phoneController.text.trim().isEmpty
                            ? 'Agrega tu telefono para identificarte mejor.'
                            : _phoneController.text.trim(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Backend actual'),
            subtitle: Text(state.baseUrl),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notificaciones',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (state.invitations.isEmpty)
                  const Text('No tienes solicitudes pendientes.')
                else
                  ...state.invitations.map(
                    (group) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: Text('Invitacion a ${group.name}'),
                      subtitle: Text(group.description.isEmpty
                          ? 'Solicitud pendiente para entrar al grupo.'
                          : group.description),
                      trailing: FilledButton(
                        onPressed: state.isBusy
                            ? null
                            : () => _runAction(
                                  context,
                                  () => state.acceptInvitation(group.id),
                                ),
                        child: const Text('Aceptar'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historial',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (state.globalFeed.isEmpty)
                  const Text('Sin historial por ahora.')
                else
                  ...state.globalFeed.take(8).map(
                        (event) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(event.groupName.isEmpty
                              ? 'Movimiento reciente'
                              : event.groupName),
                          subtitle: Text(event.message),
                        ),
                      ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Contactos',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _openContactSheet(context),
                      child: const Text('Agregar'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (state.contacts.isEmpty)
                  const Text('Todavia no has guardado contactos desde la app.')
                else
                  ...state.contacts.map(
                    (contact) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(contact.user.displayName),
                      subtitle: Text(
                        contact.nickname.trim().isEmpty
                            ? contact.user.email
                            : '${contact.nickname} · ${contact.user.email}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Editar perfil',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Usuario'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstNameController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lastNameController,
                        onChanged: (_) => setState(() {}),
                        decoration:
                            const InputDecoration(labelText: 'Apellido'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefono'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _avatarUrlController,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'URL de avatar'),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: state.isBusy ? null : () => _save(context),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar perfil'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed:
              state.isBusy ? null : () => _runAction(context, state.bootstrap),
          icon: const Icon(Icons.sync_rounded),
          label: const Text('Recargar datos'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: state.isBusy ? null : state.logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesion'),
        ),
      ],
    );
  }

  void _syncControllers(AppUser user) {
    _syncedUserId = user.id;
    _usernameController.text = user.username;
    _firstNameController.text = user.firstName;
    _lastNameController.text = user.lastName;
    _phoneController.text = user.phoneNumber;
    _avatarUrlController.text = user.avatarUrl;
  }

  String _previewDisplayName(AppUser user) {
    final composed =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();
    if (composed.isNotEmpty) {
      return composed;
    }
    final username = _usernameController.text.trim();
    return username.isNotEmpty ? username : user.displayName;
  }

  Future<void> _save(BuildContext context) async {
    final username = _usernameController.text.trim();
    if (username.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre de usuario valido.')),
      );
      return;
    }

    final state = AppScope.of(context);
    await _runAction(
      context,
      () => state.updateProfile(
        username: username,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        avatarUrl: _avatarUrlController.text.trim(),
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
    setState(() {
      _syncedUserId = null;
    });
  }

  Future<void> _openContactSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ContactSheet(),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.imageUrl,
    required this.fallbackLabel,
  });

  final String imageUrl;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) {
      return CircleAvatar(radius: 28, child: Text(fallbackLabel));
    }
    return CircleAvatar(
      radius: 28,
      backgroundImage: NetworkImage(trimmed),
      onBackgroundImageError: (_, __) {},
      child: trimmed.isEmpty ? Text(fallbackLabel) : null,
    );
  }
}

bool _matchesUserQuery(AppUser user, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  final compact = normalized.replaceAll('ppm-', '').replaceAll(' ', '');
  return user.id.toString() == normalized ||
      user.publicCode.toLowerCase().contains(normalized) ||
      user.publicCode.toLowerCase().replaceAll('ppm-', '').contains(compact) ||
      user.username.toLowerCase().contains(normalized) ||
      user.email.toLowerCase().contains(normalized) ||
      user.displayName.toLowerCase().contains(normalized);
}

String _userIdentityLine(AppUser user) {
  final code =
      user.publicCode.trim().isEmpty ? 'ID ${user.id}' : user.publicCode;
  return '$code - @${user.username}';
}

bool _canConfirmSettlement(int? currentUserId, AppSettlement settlement) {
  if (currentUserId == null || settlement.receivedConfirmed) {
    return false;
  }
  if (currentUserId == settlement.fromUser.id) {
    return !settlement.fromConfirmed;
  }
  if (currentUserId == settlement.toUser.id) {
    return !settlement.toConfirmed;
  }
  return false;
}

String _roleLabel(AppUser user) {
  switch (user.groupRole) {
    case 'host':
      return 'Anfitrion';
    case 'admin':
      return 'Admin';
    default:
      return 'Miembro';
  }
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet();

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  final _queryController = TextEditingController();
  final _nicknameController = TextEditingController();
  int? _contactUserId;

  @override
  void dispose() {
    _queryController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final currentUserId = state.currentUser?.id;
    final candidates = state.users
        .where((user) => user.id != currentUserId)
        .toList(growable: false);
    final query = _queryController.text;
    final results = candidates
        .where((user) => _matchesUserQuery(user, query))
        .take(8)
        .toList(growable: false);
    final selectedUser = candidates.cast<AppUser?>().firstWhere(
          (user) => user?.id == _contactUserId,
          orElse: () => null,
        );

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Guardar contacto',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (candidates.isEmpty)
              const Text('No hay otros usuarios disponibles para guardar.')
            else ...[
              TextField(
                controller: _queryController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Buscar por ID, codigo o usuario',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              if (query.trim().isEmpty)
                const Text('Escribe un ID numerico o codigo tipo PPM-ABC123.')
              else if (results.isEmpty)
                const Text('No encontre usuarios con esa busqueda.')
              else
                ...results.map(
                  (user) => RadioListTile<int>(
                    value: user.id,
                    groupValue: _contactUserId,
                    title: Text(user.displayName),
                    subtitle: Text(_userIdentityLine(user)),
                    onChanged: (value) =>
                        setState(() => _contactUserId = value),
                  ),
                ),
              if (selectedUser != null) ...[
                const SizedBox(height: 4),
                InputChip(
                  avatar: CircleAvatar(
                      child: Text(_initials(selectedUser.displayName))),
                  label: Text('Seleccionado: ${selectedUser.displayName}'),
                  onDeleted: () => setState(() => _contactUserId = null),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _nicknameController,
                decoration:
                    const InputDecoration(labelText: 'Apodo (opcional)'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: state.isBusy ? null : () => _submit(context),
                child: const Text('Guardar contacto'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final userId = _contactUserId;
    if (userId == null) {
      return;
    }
    final state = AppScope.of(context);
    await _runAction(
      context,
      () => state.saveContact(
        contactUserId: userId,
        nickname: _nicknameController.text.trim(),
      ),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Contacto guardado.')));
  }
}

class _ProposalSheet extends StatefulWidget {
  const _ProposalSheet({
    required this.group,
    required this.currentUserId,
  });

  final AppGroup group;
  final int? currentUserId;

  @override
  State<_ProposalSheet> createState() => _ProposalSheetState();
}

class _ProposalSheetState extends State<_ProposalSheet> {
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();
  final _amountController = TextEditingController();
  final _availabilityController = TextEditingController();
  final _providerNameController = TextEditingController();
  final _providerDetailsController = TextEditingController();
  final _providerUrlController = TextEditingController();
  final _paymentDueController = TextEditingController();
  final _scheduledForController = TextEditingController();
  final _voteDeadlineController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  String _activityType = 'actividad';
  String _confirmationStatus = 'pendiente';
  bool _isSharedDebt = true;
  int? _payerUserId;

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _amountController.dispose();
    _availabilityController.dispose();
    _providerNameController.dispose();
    _providerDetailsController.dispose();
    _providerUrlController.dispose();
    _paymentDueController.dispose();
    _scheduledForController.dispose();
    _voteDeadlineController.dispose();
    _paymentMethodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nueva propuesta',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titulo')),
            const SizedBox(height: 12),
            TextField(
                controller: _detailsController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Detalles')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _activityType,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem<String>(
                    value: 'comida', child: Text('Comida')),
                DropdownMenuItem<String>(
                    value: 'actividad', child: Text('Actividad')),
                DropdownMenuItem<String>(value: 'lugar', child: Text('Lugar')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _activityType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto total'),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: _availabilityController,
                decoration: const InputDecoration(labelText: 'Disponibilidad')),
            const SizedBox(height: 12),
            TextField(
                controller: _providerNameController,
                decoration: const InputDecoration(labelText: 'Proveedor')),
            const SizedBox(height: 12),
            TextField(
                controller: _providerDetailsController,
                decoration:
                    const InputDecoration(labelText: 'Detalles del proveedor')),
            const SizedBox(height: 12),
            TextField(
                controller: _providerUrlController,
                keyboardType: TextInputType.url,
                decoration:
                    const InputDecoration(labelText: 'URL del proveedor')),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _payerUserId,
              decoration:
                  const InputDecoration(labelText: 'Quien paga (opcional)'),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('Sin definir')),
                ...widget.group.members.map(
                  (user) => DropdownMenuItem<int?>(
                      value: user.id, child: Text(user.displayName)),
                ),
              ],
              onChanged: (value) => setState(() => _payerUserId = value),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: _paymentDueController,
                decoration:
                    const InputDecoration(labelText: 'Fecha limite de pago')),
            const SizedBox(height: 12),
            TextField(
                controller: _scheduledForController,
                decoration: const InputDecoration(labelText: 'Fecha planeada')),
            const SizedBox(height: 12),
            TextField(
                controller: _voteDeadlineController,
                decoration:
                    const InputDecoration(labelText: 'Cierre de votacion')),
            const SizedBox(height: 12),
            TextField(
                controller: _paymentMethodController,
                decoration: const InputDecoration(labelText: 'Metodo de pago')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _confirmationStatus,
              decoration:
                  const InputDecoration(labelText: 'Estado de confirmacion'),
              items: const [
                DropdownMenuItem<String>(
                    value: 'pendiente', child: Text('Pendiente')),
                DropdownMenuItem<String>(
                    value: 'confirmado', child: Text('Confirmado')),
                DropdownMenuItem<String>(
                    value: 'cancelado', child: Text('Cancelado')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _confirmationStatus = value);
                }
              },
            ),
            SwitchListTile(
              value: _isSharedDebt,
              contentPadding: EdgeInsets.zero,
              title: const Text('Compartir deuda'),
              onChanged: (value) => setState(() => _isSharedDebt = value),
            ),
            FilledButton(
              onPressed: state.isBusy ? null : () => _submit(context),
              child: const Text('Guardar propuesta'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (title.length < 2 || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Completa un titulo valido y un monto mayor a cero.')),
      );
      return;
    }
    final state = AppScope.of(context);
    await _runAction(
      context,
      () => state.createProposal(
        groupId: widget.group.id,
        title: title,
        details: _detailsController.text.trim(),
        activityType: _activityType,
        totalAmount: amount,
        availabilityText: _availabilityController.text.trim(),
        providerName: _providerNameController.text.trim(),
        providerDetails: _providerDetailsController.text.trim(),
        providerUrl: _providerUrlController.text.trim(),
        payerUserId: _payerUserId,
        paymentDueDate: _paymentDueController.text.trim(),
        scheduledForDate: _scheduledForController.text.trim(),
        voteDeadline: _voteDeadlineController.text.trim(),
        paymentMethod: _paymentMethodController.text.trim(),
        confirmationStatus: _confirmationStatus,
        isSharedDebt: _isSharedDebt,
      ),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Propuesta guardada.')));
  }
}

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({
    required this.group,
    required this.currentUserId,
  });

  final AppGroup group;
  final int? currentUserId;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  final _titleController = TextEditingController();
  final _commentController = TextEditingController();
  int _score = 5;
  int? _ratedUserId;

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final candidates = widget.group.members
        .where((member) => member.id != widget.currentUserId)
        .toList(growable: false);
    _ratedUserId ??= candidates.isNotEmpty ? candidates.first.id : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Calificar persona',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (candidates.isEmpty)
              const Text(
                  'Necesitas al menos otra persona en el grupo para calificar.')
            else ...[
              DropdownButtonFormField<int>(
                initialValue: _ratedUserId,
                decoration: const InputDecoration(labelText: 'Persona'),
                items: candidates
                    .map((member) => DropdownMenuItem<int>(
                        value: member.id, child: Text(member.displayName)))
                    .toList(growable: false),
                onChanged: (value) => setState(() => _ratedUserId = value),
              ),
              const SizedBox(height: 12),
              Text('Puntaje: $_score/5'),
              Slider(
                value: _score.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$_score',
                onChanged: (value) => setState(() => _score = value.round()),
              ),
              TextField(
                  controller: _titleController,
                  decoration:
                      const InputDecoration(labelText: 'Titulo de la reseña')),
              const SizedBox(height: 12),
              TextField(
                  controller: _commentController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Comentario')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: state.isBusy ? null : () => _submit(context),
                child: const Text('Guardar calificacion'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final ratedUserId = _ratedUserId;
    final title = _titleController.text.trim();
    if (ratedUserId == null || title.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Elige una persona y escribe un titulo valido.')),
      );
      return;
    }
    final state = AppScope.of(context);
    await _runAction(
      context,
      () => state.createRating(
        groupId: widget.group.id,
        ratedUserId: ratedUserId,
        score: _score,
        title: title,
        comment: _commentController.text.trim(),
      ),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Calificacion guardada.')));
  }
}

class _SettlementSheet extends StatefulWidget {
  const _SettlementSheet({
    required this.group,
    required this.currentUserId,
  });

  final AppGroup group;
  final int? currentUserId;

  @override
  State<_SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<_SettlementSheet> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  late int _fromUserId;
  late int _toUserId;

  @override
  void initState() {
    super.initState();
    final currentUserId = widget.currentUserId;
    _fromUserId =
        widget.group.members.any((member) => member.id == currentUserId)
            ? currentUserId!
            : widget.group.members.first.id;
    _toUserId = widget.group.members
        .firstWhere(
          (member) => member.id != _fromUserId,
          orElse: () => widget.group.members.first,
        )
        .id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Registrar liquidacion',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(widget.group.name,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _fromUserId,
              decoration: const InputDecoration(labelText: 'Quien paga'),
              items: widget.group.members
                  .map((member) => DropdownMenuItem<int>(
                      value: member.id, child: Text(member.displayName)))
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _fromUserId = value;
                  if (_toUserId == _fromUserId) {
                    _toUserId = widget.group.members
                        .firstWhere(
                          (member) => member.id != _fromUserId,
                          orElse: () => widget.group.members.first,
                        )
                        .id;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _toUserId,
              decoration: const InputDecoration(labelText: 'Quien recibe'),
              items: widget.group.members
                  .map((member) => DropdownMenuItem<int>(
                      value: member.id, child: Text(member.displayName)))
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _toUserId = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: state.isBusy ? null : () => _submit(context),
              child: const Text('Guardar liquidacion'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0 || _fromUserId == _toUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Completa monto valido y dos usuarios distintos.')),
      );
      return;
    }

    final state = AppScope.of(context);
    try {
      await state.createSettlement(
        groupId: widget.group.id,
        fromUserId: _fromUserId,
        toUserId: _toUserId,
        amount: amount,
        notes: _notesController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Liquidacion guardada.')));
    } on ApiException catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _ExpenseComposerSheet extends StatefulWidget {
  const _ExpenseComposerSheet({
    required this.group,
    required this.currentUserId,
  });

  final AppGroup group;
  final int? currentUserId;

  @override
  State<_ExpenseComposerSheet> createState() => _ExpenseComposerSheetState();
}

class _ExpenseComposerSheetState extends State<_ExpenseComposerSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  late int _payerId;
  late final Set<int> _participantIds;

  @override
  void initState() {
    super.initState();
    final defaultPayer = widget.currentUserId;
    _payerId = widget.group.members.any((member) => member.id == defaultPayer)
        ? defaultPayer!
        : widget.group.members.first.id;
    _participantIds = widget.group.members.map((member) => member.id).toSet();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Agregar gasto rapido',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(widget.group.name,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descripcion'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _payerId,
              decoration: const InputDecoration(labelText: 'Pago'),
              items: widget.group.members
                  .map((member) => DropdownMenuItem<int>(
                      value: member.id, child: Text(member.displayName)))
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _payerId = value);
              },
            ),
            const SizedBox(height: 16),
            Text('Se divide entre',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...widget.group.members.map(
              (member) => CheckboxListTile(
                value: _participantIds.contains(member.id),
                title: Text(member.displayName),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _participantIds.add(member.id);
                    } else {
                      _participantIds.remove(member.id);
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: state.isBusy ? null : () => _submit(context),
              child: const Text('Guardar gasto'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null ||
        amount <= 0 ||
        _participantIds.isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Completa monto, descripcion y al menos un participante.')),
      );
      return;
    }

    final state = AppScope.of(context);
    try {
      await state.createExpense(
        groupId: widget.group.id,
        payerId: _payerId,
        description: _descriptionController.text.trim(),
        amount: amount,
        participantIds: _participantIds.toList(growable: false),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gasto guardado.')));
    } on ApiException catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _InviteMemberSheet extends StatefulWidget {
  const _InviteMemberSheet({required this.group});

  final AppGroup group;

  @override
  State<_InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends State<_InviteMemberSheet> {
  final _queryController = TextEditingController();
  int? _selectedUserId;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final memberIds = widget.group.members.map((user) => user.id).toSet();
    final candidates = state.users
        .where((user) => !memberIds.contains(user.id))
        .toList(growable: false);
    final query = _queryController.text;
    final results = candidates
        .where((user) => _matchesUserQuery(user, query))
        .take(8)
        .toList(growable: false);
    final selectedUser = candidates.cast<AppUser?>().firstWhere(
          (user) => user?.id == _selectedUserId,
          orElse: () => null,
        );

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Invitar al grupo',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(widget.group.name,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            TextField(
              controller: _queryController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'ID o codigo de invitacion',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if (candidates.isEmpty)
              const Text('Todos los usuarios disponibles ya estan en el grupo.')
            else if (query.trim().isEmpty)
              const Text('Pide el codigo a la otra persona y buscalo aqui.')
            else if (results.isEmpty)
              const Text('No encontre usuarios con esa busqueda.')
            else
              ...results.map(
                (user) => RadioListTile<int>(
                  value: user.id,
                  groupValue: _selectedUserId,
                  title: Text(user.displayName),
                  subtitle: Text(_userIdentityLine(user)),
                  onChanged: (value) => setState(() => _selectedUserId = value),
                ),
              ),
            if (selectedUser != null) ...[
              const SizedBox(height: 4),
              InputChip(
                avatar: CircleAvatar(
                    child: Text(_initials(selectedUser.displayName))),
                label: Text('Invitar: ${selectedUser.displayName}'),
                onDeleted: () => setState(() => _selectedUserId = null),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.isBusy || _selectedUserId == null
                  ? null
                  : () => _submit(context),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Agregar al grupo'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final userId = _selectedUserId;
    if (userId == null) {
      return;
    }
    final state = AppScope.of(context);
    await _runAction(
      context,
      () => state.addMemberToGroup(groupId: widget.group.id, userId: userId),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Miembro agregado.')));
  }
}

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet();

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _endsAtController = TextEditingController();
  final _inviteSearchController = TextEditingController();
  final Set<int> _memberIds = <int>{};
  String _autoCloseAction = 'none';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _endsAtController.dispose();
    _inviteSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final currentUserId = state.currentUser?.id;
    final invitees = state.users
        .where((user) => user.id != currentUserId)
        .toList(growable: false);
    final inviteQuery = _inviteSearchController.text;
    final inviteResults = invitees
        .where((user) => _matchesUserQuery(user, inviteQuery))
        .take(8)
        .toList(growable: false);
    final selectedInvitees = invitees
        .where((user) => _memberIds.contains(user.id))
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Crear grupo',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre del grupo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripcion corta'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _endsAtController,
              decoration: const InputDecoration(
                labelText: 'Fecha final del grupo (opcional)',
                helperText: 'Formato: 2026-05-15T21:00:00',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _autoCloseAction,
              decoration: const InputDecoration(labelText: 'Accion al vencer'),
              items: const [
                DropdownMenuItem<String>(
                    value: 'none', child: Text('No hacer nada')),
                DropdownMenuItem<String>(
                    value: 'suspend', child: Text('Suspender grupo')),
                DropdownMenuItem<String>(
                    value: 'delete', child: Text('Eliminar grupo')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _autoCloseAction = value);
              },
            ),
            const SizedBox(height: 16),
            Text('Invitar personas',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (invitees.isEmpty)
              const Text(
                  'No hay otros usuarios disponibles. Puedes crear el grupo y agregar gastos contigo mismo para probar.')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _inviteSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Buscar por ID o codigo de invitacion',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (selectedInvitees.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedInvitees
                          .map(
                            (user) => InputChip(
                              label: Text(user.displayName),
                              onDeleted: () =>
                                  setState(() => _memberIds.remove(user.id)),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  if (inviteQuery.trim().isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Busca a alguien por ID o por PPM-ABC123.'),
                    )
                  else if (inviteResults.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('No encontre usuarios con esa busqueda.'),
                    )
                  else
                    ...inviteResults.map(
                      (user) => CheckboxListTile(
                        value: _memberIds.contains(user.id),
                        title: Text(user.displayName),
                        subtitle: Text(_userIdentityLine(user)),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _memberIds.add(user.id);
                            } else {
                              _memberIds.remove(user.id);
                            }
                          });
                        },
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: state.isBusy ? null : () => _submit(context),
              child: const Text('Crear grupo'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (_nameController.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre de grupo valido.')),
      );
      return;
    }

    final state = AppScope.of(context);
    try {
      await state.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        memberIds: _memberIds.toList(growable: false),
        endsAt: _endsAtController.text.trim(),
        autoCloseAction: _autoCloseAction,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Grupo creado.')));
    } on ApiException catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _runAction(
    BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } on ApiException catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.message)));
  }
}

String _expenseHeadline(AppState state, AppExpense expense) {
  final currentUserId = state.currentUser?.id;
  if (currentUserId == null) {
    return '${expense.payer.displayName} pago ${money(expense.amount)}';
  }

  final myShare =
      expense.participants.cast<AppExpenseParticipant?>().firstWhere(
            (item) => item?.id == currentUserId,
            orElse: () => null,
          );

  if (expense.payer.id == currentUserId) {
    final othersOwe = expense.participants
        .where((participant) => participant.id != currentUserId)
        .fold<double>(0, (total, item) => total + item.shareAmount);
    if (othersOwe > 0) {
      return 'Pagaste ${money(expense.amount)} · Te deben ${money(othersOwe)}';
    }
    return 'Pagaste ${money(expense.amount)}';
  }

  if (myShare != null) {
    return '${expense.payer.displayName} pago ${money(expense.amount)} · Tu debes ${money(myShare.shareAmount)}';
  }

  return '${expense.payer.displayName} pago ${money(expense.amount)}';
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'P';
  }
  final firstTwo =
      parts.take(2).map((part) => part.substring(0, 1).toUpperCase()).join();
  return firstTwo.isEmpty ? 'P' : firstTwo;
}

({Color background, Color border}) _summaryPalette(
    SummaryTone tone, ThemeData theme) {
  switch (tone) {
    case SummaryTone.positive:
      return (
        background: const Color(0x1F1F7A4D),
        border: const Color(0x661F7A4D),
      );
    case SummaryTone.negative:
      return (
        background: const Color(0x1FB63F2E),
        border: const Color(0x66B63F2E),
      );
    case SummaryTone.action:
      return (
        background: const Color(0x1F21455B),
        border: const Color(0x6621455B),
      );
    case SummaryTone.neutral:
      return (
        background: theme.colorScheme.primary.withOpacity(0.08),
        border: theme.colorScheme.primary.withOpacity(0.22),
      );
  }
}
