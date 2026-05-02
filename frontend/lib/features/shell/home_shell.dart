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
  int _groupTab = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(_navIndex)),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: state.isBusy ? null : () => _runAction(context, state.bootstrap),
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
                    groupTab: _groupTab,
                    onChangeGroupTab: (value) => setState(() => _groupTab = value),
                    onOpenExpense: () => _showExpenseSheet(context),
                    onOpenCreateGroup: () => _showCreateGroupSheet(context),
                  ),
                  const _HistoryTab(),
                  const _AccountTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _navIndex == 0 && state.activeGroup != null
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
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Historial',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Cuenta'),
        ],
      ),
    );
  }

  String _titleForIndex(int value) {
    switch (value) {
      case 1:
        return 'Historial';
      case 2:
        return 'Cuenta';
      default:
        return 'PPM Mobile';
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
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.groupTab,
    required this.onChangeGroupTab,
    required this.onOpenExpense,
    required this.onOpenCreateGroup,
  });

  final int groupTab;
  final ValueChanged<int> onChangeGroupTab;
  final VoidCallback onOpenExpense;
  final VoidCallback onOpenCreateGroup;

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
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Tu app movil debe decirte rapido quien debe, que grupo sigue y como registrar el siguiente gasto.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          if (state.groups.isEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sin grupos todavia', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
              height: 48,
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
                    onSelected: (_) => _runAction(context, () => state.selectGroup(group.id)),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (state.activeGroup != null) ...[
              _GroupHeroCard(
                onOpenExpense: onOpenExpense,
                onOpenBalances: () => onChangeGroupTab(1),
              ),
              const SizedBox(height: 14),
              _MemberPreview(members: state.activeGroup!.members),
              const SizedBox(height: 14),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(value: 0, icon: Icon(Icons.receipt_rounded), label: Text('Gastos')),
                  ButtonSegment<int>(value: 1, icon: Icon(Icons.balance_rounded), label: Text('Saldos')),
                ],
                selected: {groupTab},
                onSelectionChanged: (values) => onChangeGroupTab(values.first),
              ),
              const SizedBox(height: 14),
              if (groupTab == 0) _ExpensesSection(onOpenExpense: onOpenExpense) else const _BalancesSection(),
            ],
          ],
        ],
      ),
    );
  }
}

class _GroupHeroCard extends StatelessWidget {
  const _GroupHeroCard({
    required this.onOpenExpense,
    required this.onOpenBalances,
  });

  final VoidCallback onOpenExpense;
  final VoidCallback onOpenBalances;

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
            Text(group.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              group.description.isEmpty ? 'Sin descripcion. Todo listo para probar el flujo movil.' : group.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                  Text(summary.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
          ],
        ),
      ),
    );
  }
}

class _MemberPreview extends StatelessWidget {
  const _MemberPreview({required this.members});

  final List<AppUser> members;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: members
              .map(
                (user) => Chip(
                  avatar: CircleAvatar(child: Text(_initials(user.displayName))),
                  label: Text(user.displayName),
                ),
              )
              .toList(growable: false),
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
              Text('Aun no hay gastos. Agrega uno para empezar a dividir.', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '1. Agrega un gasto  2. Se divide automaticamente  3. Revisa quien debe a quien',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onOpenExpense, child: const Text('Agregar primer gasto')),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(expense.description),
                subtitle: Text(
                  '${_expenseHeadline(state, expense)}\n${formatDate(expense.createdAt)}',
                ),
                isThreeLine: true,
                trailing: Text(
                  money(expense.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _BalancesSection extends StatelessWidget {
  const _BalancesSection();

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
        ...balances.entries.map(
          (entry) => Card(
            child: ListTile(
              title: Text(entry.user.displayName),
              subtitle: Text('Pago ${money(entry.paid)} · Debe ${money(entry.owed)}'),
              trailing: Text(
                entry.net == 0 ? 'Parejo' : (entry.net > 0 ? '+${money(entry.net)}' : '-${money(entry.net.abs())}'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: entry.net >= 0 ? const Color(0xFF1F7A4D) : const Color(0xFFB63F2E),
                    ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Sugerencias para saldar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
                title: Text('${item.fromUser.displayName} debe pagar a ${item.toUser.displayName}'),
                trailing: Text(
                  money(item.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.globalFeed.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              title: Text('Sin historial por ahora'),
              subtitle: Text('Cuando alguien pague, agregue un gasto o salde una deuda, lo veras aqui con contexto util.'),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: state.globalFeed
          .map(
            (event) => Card(
              child: ListTile(
                title: Text(event.groupName.isEmpty ? 'Movimiento reciente' : event.groupName),
                subtitle: Text(event.message),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AccountTab extends StatelessWidget {
  const _AccountTab();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(radius: 26, child: Text(_initials(user.displayName))),
            title: Text(user.displayName),
            subtitle: Text(user.email),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Backend actual'),
            subtitle: Text(state.baseUrl),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Telefono'),
            subtitle: Text(user.phoneNumber.isEmpty ? 'Sin telefono guardado' : user.phoneNumber),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: state.isBusy ? null : () => _runAction(context, state.bootstrap),
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
            Text('Agregar gasto rapido', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(widget.group.name, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  .map((member) => DropdownMenuItem<int>(value: member.id, child: Text(member.displayName)))
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _payerId = value);
              },
            ),
            const SizedBox(height: 16),
            Text('Se divide entre', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
    if (amount == null || amount <= 0 || _participantIds.isEmpty || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa monto, descripcion y al menos un participante.')),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gasto guardado.')));
    } on ApiException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
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
  final Set<int> _memberIds = <int>{};

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final currentUserId = state.currentUser?.id;
    final invitees = state.users.where((user) => user.id != currentUserId).toList(growable: false);

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
            Text('Crear grupo', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
            Text('Invitar personas', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (invitees.isEmpty)
              const Text('No hay otros usuarios disponibles. Puedes crear el grupo y agregar gastos contigo mismo para probar.')
            else
              ...invitees.map(
                (user) => CheckboxListTile(
                  value: _memberIds.contains(user.id),
                  title: Text(user.displayName),
                  subtitle: Text(user.email),
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
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grupo creado.')));
    } on ApiException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _runAction(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } on ApiException catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
  }
}

String _expenseHeadline(AppState state, AppExpense expense) {
  final currentUserId = state.currentUser?.id;
  if (currentUserId == null) {
    return '${expense.payer.displayName} pago ${money(expense.amount)}';
  }

  final myShare = expense.participants.cast<AppExpenseParticipant?>().firstWhere(
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
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.isEmpty) {
    return 'P';
  }
  final firstTwo = parts.take(2).map((part) => part.substring(0, 1).toUpperCase()).join();
  return firstTwo.isEmpty ? 'P' : firstTwo;
}

({Color background, Color border}) _summaryPalette(SummaryTone tone, ThemeData theme) {
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
