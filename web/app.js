const API_BASE = "";

const VIEW_META = {
  dashboard: {
    title: "Prueben decisiones reales entre amigos antes de ir a movil.",
    subtitle: "Dashboard con resumen del grupo, feed y la propuesta seleccionada.",
  },
  groups: {
    title: "El anfitrion y el grupo mandan.",
    subtitle: "Gestiona miembros, anfitrion y decisiones fuertes como eliminar el grupo.",
  },
  expenses: {
    title: "Las deudas compartidas ya viven en serio aqui.",
    subtitle: "Registra gastos, reparte participantes y elimina deudas por votacion.",
  },
  balances: {
    title: "Balance claro, sin dramas.",
    subtitle: "Ve quien debe a quien y marca liquidaciones manuales cuando ya pagaron.",
  },
  feed: {
    title: "El feed social es el distintivo.",
    subtitle: "Cada gasto, voto, liquidacion o propuesta queda visible para el grupo.",
  },
  stats: {
    title: "Las decisiones tambien necesitan lectura.",
    subtitle: "Revisa gasto por usuario, votos por propuesta y actividad del grupo.",
  },
  proposals: {
    title: "Aportacion de idea, votacion y eleccion.",
    subtitle: "Planea comida, actividad o lugar con datos de proveedor y especificaciones de pago.",
  },
  community: {
    title: "La reputacion social tambien cuenta.",
    subtitle: "Califiquen usuarios con titulos y dejen memoria de quien si cumple.",
  },
};

const state = {
  currentUser: loadJson("ppm-current-user"),
  groups: [],
  users: [],
  summary: null,
  activeGroupId: loadNumber("ppm-active-group-id"),
  activeGroup: null,
  expenses: [],
  balances: null,
  feed: [],
  proposals: [],
  ratings: { leaderboard: [], ratings: [] },
  stats: null,
  settlements: [],
  activeView: localStorage.getItem("ppm-active-view") || "dashboard",
};

const authView = document.getElementById("auth-view");
const appView = document.getElementById("app-view");
const toastEl = document.getElementById("toast");

const loginForm = document.getElementById("login-form");
const registerForm = document.getElementById("register-form");
const groupForm = document.getElementById("group-form");
const expenseForm = document.getElementById("expense-form");
const manualSettlementForm = document.getElementById("manual-settlement-form");
const proposalForm = document.getElementById("proposal-form");
const ratingForm = document.getElementById("rating-form");

document.getElementById("show-login").addEventListener("click", () => toggleAuthMode("login"));
document.getElementById("show-register").addEventListener("click", () => toggleAuthMode("register"));
document.getElementById("logout-btn").addEventListener("click", logout);
document.getElementById("refresh-groups-btn").addEventListener("click", bootstrapApp);
document.getElementById("reload-all-btn").addEventListener("click", bootstrapApp);
document.getElementById("add-member-btn").addEventListener("click", handleAddMember);
document.getElementById("group-delete-vote-btn").addEventListener("click", handleGroupDeleteVote);

loginForm.addEventListener("submit", handleLogin);
registerForm.addEventListener("submit", handleRegister);
groupForm.addEventListener("submit", handleCreateGroup);
expenseForm.addEventListener("submit", handleCreateExpense);
manualSettlementForm.addEventListener("submit", handleCreateSettlement);
proposalForm.addEventListener("submit", handleCreateProposal);
ratingForm.addEventListener("submit", handleCreateRating);

document.querySelectorAll(".nav-btn").forEach((button) => {
  button.addEventListener("click", () => setActiveView(button.dataset.view));
});

toggleAuthMode("login");
renderApp();
if (state.currentUser) {
  bootstrapApp();
}

function loadJson(key) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function loadNumber(key) {
  const raw = localStorage.getItem(key);
  return raw ? Number(raw) : null;
}

function persistState() {
  if (state.currentUser) {
    localStorage.setItem("ppm-current-user", JSON.stringify(state.currentUser));
  } else {
    localStorage.removeItem("ppm-current-user");
  }

  if (state.activeGroupId) {
    localStorage.setItem("ppm-active-group-id", String(state.activeGroupId));
  } else {
    localStorage.removeItem("ppm-active-group-id");
  }

  localStorage.setItem("ppm-active-view", state.activeView);
}

async function api(path, options = {}) {
  const response = await fetch(`${API_BASE}${path}`, {
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
    ...options,
  });

  if (!response.ok) {
    let message = "No se pudo completar la accion.";
    try {
      const data = await response.json();
      message = data.detail || message;
    } catch {
      // ignore
    }
    throw new Error(message);
  }

  const contentType = response.headers.get("content-type") || "";
  if (contentType.includes("application/json")) {
    return response.json();
  }
  return null;
}

function toggleAuthMode(mode) {
  const loginActive = mode === "login";
  loginForm.classList.toggle("hidden", !loginActive);
  registerForm.classList.toggle("hidden", loginActive);
  document.getElementById("show-login").classList.toggle("active", loginActive);
  document.getElementById("show-register").classList.toggle("active", !loginActive);
}

function setActiveView(view) {
  state.activeView = view;
  persistState();
  renderApp();
}

async function handleLogin(event) {
  event.preventDefault();
  const formData = new FormData(loginForm);
  try {
    const result = await api("/auth/login", {
      method: "POST",
      body: JSON.stringify({
        email: formData.get("email"),
        password: formData.get("password"),
      }),
    });
    state.currentUser = result.user;
    persistState();
    showToast("Sesion iniciada.", "success");
    loginForm.reset();
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleRegister(event) {
  event.preventDefault();
  const formData = new FormData(registerForm);
  try {
    const result = await api("/auth/register", {
      method: "POST",
      body: JSON.stringify({
        username: formData.get("username"),
        email: formData.get("email"),
        password: formData.get("password"),
      }),
    });
    state.currentUser = result.user;
    persistState();
    showToast("Cuenta creada.", "success");
    registerForm.reset();
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

function logout() {
  state.currentUser = null;
  state.groups = [];
  state.users = [];
  state.summary = null;
  state.activeGroupId = null;
  state.activeGroup = null;
  state.expenses = [];
  state.balances = null;
  state.feed = [];
  state.proposals = [];
  state.ratings = { leaderboard: [], ratings: [] };
  state.stats = null;
  state.settlements = [];
  persistState();
  renderApp();
}

async function bootstrapApp() {
  if (!state.currentUser) {
    renderApp();
    return;
  }

  try {
    const [users, groups, summary] = await Promise.all([
      api("/users"),
      api(`/users/${state.currentUser.id}/groups`),
      api(`/users/${state.currentUser.id}/summary`),
    ]);

    state.users = users;
    state.groups = groups;
    state.summary = summary;

    if (!state.groups.length) {
      state.activeGroupId = null;
      state.activeGroup = null;
      state.expenses = [];
      state.balances = null;
      state.feed = [];
      state.proposals = [];
      state.ratings = { leaderboard: [], ratings: [] };
      state.stats = null;
      state.settlements = [];
      persistState();
      renderApp();
      return;
    }

    if (!state.groups.some((group) => group.id === state.activeGroupId)) {
      state.activeGroupId = state.groups[0].id;
    }

    persistState();
    await loadActiveGroupData();
    renderApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function loadActiveGroupData() {
  if (!state.activeGroupId) {
    state.activeGroup = null;
    state.expenses = [];
    state.balances = null;
    state.feed = [];
    state.proposals = [];
    state.ratings = { leaderboard: [], ratings: [] };
    state.stats = null;
    state.settlements = [];
    return;
  }

  const [group, expenses, balances, feed, proposals, ratings, stats, settlements] = await Promise.all([
    api(`/groups/${state.activeGroupId}`),
    api(`/groups/${state.activeGroupId}/expenses`),
    api(`/groups/${state.activeGroupId}/balances`),
    api(`/groups/${state.activeGroupId}/feed`),
    api(`/groups/${state.activeGroupId}/proposals`),
    api(`/groups/${state.activeGroupId}/ratings`),
    api(`/groups/${state.activeGroupId}/stats`),
    api(`/groups/${state.activeGroupId}/settlements`),
  ]);

  state.activeGroup = group;
  state.expenses = expenses;
  state.balances = balances;
  state.feed = feed;
  state.proposals = proposals;
  state.ratings = ratings;
  state.stats = stats;
  state.settlements = settlements;
}

async function handleCreateGroup(event) {
  event.preventDefault();
  const formData = new FormData(groupForm);
  const invitedIds = Array.from(document.getElementById("group-invite-list").selectedOptions).map((option) =>
    Number(option.value)
  );

  try {
    const group = await api("/groups", {
      method: "POST",
      body: JSON.stringify({
        name: formData.get("name"),
        description: formData.get("description"),
        creator_id: state.currentUser.id,
        member_ids: invitedIds,
      }),
    });
    state.activeGroupId = group.id;
    groupForm.reset();
    persistState();
    showToast("Grupo creado.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleAddMember() {
  if (!state.activeGroupId) {
    return;
  }
  const select = document.getElementById("member-add-select");
  const userId = Number(select.value);
  if (!userId) {
    return;
  }

  try {
    await api(`/groups/${state.activeGroupId}/members`, {
      method: "POST",
      body: JSON.stringify({ user_id: userId }),
    });
    showToast("Miembro agregado.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleCreateExpense(event) {
  event.preventDefault();
  if (!state.activeGroup) {
    return;
  }

  const formData = new FormData(expenseForm);
  const participantIds = Array.from(document.querySelectorAll('input[name="participantIds"]:checked')).map((input) =>
    Number(input.value)
  );

  try {
    await api("/expenses", {
      method: "POST",
      body: JSON.stringify({
        group_id: state.activeGroup.id,
        payer_id: Number(formData.get("payerId")),
        description: formData.get("description"),
        amount: Number(formData.get("amount")),
        participant_ids: participantIds,
      }),
    });
    expenseForm.reset();
    showToast("Gasto guardado.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleVoteDeleteExpense(expenseId) {
  try {
    const result = await api(`/expenses/${expenseId}/delete-vote`, {
      method: "POST",
      body: JSON.stringify({
        user_id: state.currentUser.id,
        mode: "majority",
      }),
    });
    showToast(result.deleted ? "Deuda eliminada por votacion." : "Voto registrado.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleCreateSettlement(event) {
  event.preventDefault();
  if (!state.activeGroup) {
    return;
  }

  const formData = new FormData(manualSettlementForm);
  try {
    await api(`/groups/${state.activeGroup.id}/settlements`, {
      method: "POST",
      body: JSON.stringify({
        actor_id: state.currentUser.id,
        from_user_id: Number(formData.get("fromUserId")),
        to_user_id: Number(formData.get("toUserId")),
        amount: Number(formData.get("amount")),
        notes: formData.get("notes"),
      }),
    });
    manualSettlementForm.reset();
    showToast("Liquidacion manual guardada.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleCreateProposal(event) {
  event.preventDefault();
  if (!state.activeGroup) {
    return;
  }

  const formData = new FormData(proposalForm);
  const payerValue = formData.get("payerUserId");

  try {
    await api(`/groups/${state.activeGroup.id}/proposals`, {
      method: "POST",
      body: JSON.stringify({
        creator_id: state.currentUser.id,
        title: formData.get("title"),
        details: formData.get("details"),
        activity_type: formData.get("activityType"),
        availability_text: formData.get("availabilityText"),
        provider_name: formData.get("providerName"),
        provider_details: formData.get("providerDetails"),
        payer_user_id: payerValue ? Number(payerValue) : null,
        payment_due_date: formData.get("paymentDueDate"),
        scheduled_for_date: formData.get("scheduledForDate"),
        total_amount: Number(formData.get("totalAmount")),
        payment_method: formData.get("paymentMethod"),
        confirmation_status: formData.get("confirmationStatus"),
        is_shared_debt: formData.get("isSharedDebt") === "on",
      }),
    });
    proposalForm.reset();
    showToast("Propuesta creada.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleVoteProposal(proposalId) {
  try {
    await api(`/proposals/${proposalId}/vote`, {
      method: "POST",
      body: JSON.stringify({ user_id: state.currentUser.id }),
    });
    showToast("Voto registrado.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleSelectProposal(proposalId) {
  try {
    await api(`/proposals/${proposalId}/select`, {
      method: "POST",
      body: JSON.stringify({ user_id: state.currentUser.id }),
    });
    showToast("Propuesta elegida.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleCreateRating(event) {
  event.preventDefault();
  if (!state.activeGroup) {
    return;
  }
  const formData = new FormData(ratingForm);

  try {
    await api(`/groups/${state.activeGroup.id}/ratings`, {
      method: "POST",
      body: JSON.stringify({
        rater_id: state.currentUser.id,
        rated_user_id: Number(formData.get("ratedUserId")),
        score: Number(formData.get("score")),
        title: formData.get("title"),
        comment: formData.get("comment"),
      }),
    });
    ratingForm.reset();
    showToast("Calificacion guardada.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleGroupDeleteVote() {
  if (!state.activeGroup) {
    return;
  }
  const mode = document.getElementById("group-delete-mode").value;

  try {
    const result = await api(`/groups/${state.activeGroup.id}/delete-vote`, {
      method: "POST",
      body: JSON.stringify({
        user_id: state.currentUser.id,
        mode,
      }),
    });
    showToast(result.deleted ? "El grupo se elimino por votacion." : "Voto para eliminar grupo registrado.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

function renderApp() {
  const loggedIn = Boolean(state.currentUser);
  authView.classList.toggle("hidden", loggedIn);
  appView.classList.toggle("hidden", !loggedIn);

  if (!loggedIn) {
    return;
  }

  document.getElementById("current-user-name").textContent = state.currentUser.username;
  document.getElementById("current-user-email").textContent = state.currentUser.email;

  renderHero();
  renderNav();
  renderMetrics();
  renderGroups();
  renderGroupCore();
  renderExpenseForm();
  renderExpenses();
  renderBalances();
  renderFeed();
  renderFeedPreview();
  renderRecentExpenses();
  renderInviteOptions();
  renderStats();
  renderProposals();
  renderRatings();
  renderSelectedProposal();
  renderViewVisibility();
}

function renderHero() {
  const meta = VIEW_META[state.activeView] || VIEW_META.dashboard;
  document.getElementById("hero-title").textContent = meta.title;
  document.getElementById("hero-subtitle").textContent = meta.subtitle;
}

function renderNav() {
  document.querySelectorAll(".nav-btn").forEach((button) => {
    button.classList.toggle("active", button.dataset.view === state.activeView);
  });
}

function renderMetrics() {
  const summary = state.summary || {
    total_expenses: 0,
    total_paid: 0,
    net_balance: 0,
    proposal_count: 0,
  };
  document.getElementById("metric-total-expenses").textContent = money(summary.total_expenses);
  document.getElementById("metric-total-paid").textContent = money(summary.total_paid);
  document.getElementById("metric-net-balance").textContent = money(summary.net_balance);
  document.getElementById("metric-proposal-count").textContent = String(summary.proposal_count || 0);
}

function renderGroups() {
  const wrap = document.getElementById("group-list");
  wrap.innerHTML = "";

  if (!state.groups.length) {
    wrap.innerHTML = '<div class="group-item muted small">Todavia no hay grupos.</div>';
    return;
  }

  state.groups.forEach((group) => {
    const item = document.createElement("article");
    item.className = `group-item ${group.id === state.activeGroupId ? "active" : ""}`;
    item.innerHTML = `
      <button type="button">
        <strong>${escapeHtml(group.name)}</strong>
        <div class="muted small">${escapeHtml(group.description || "Sin descripcion")}</div>
      </button>
    `;
    item.querySelector("button").addEventListener("click", async () => {
      state.activeGroupId = group.id;
      persistState();
      await loadActiveGroupData();
      renderApp();
    });
    wrap.appendChild(item);
  });
}

function renderGroupCore() {
  const activeName = document.getElementById("active-group-name");
  const activeDescription = document.getElementById("active-group-description");
  const hostLine = document.getElementById("active-group-host");
  const memberWrap = document.getElementById("active-group-members");
  const membersDetail = document.getElementById("group-members-detail");
  const deleteSummary = document.getElementById("group-delete-summary");
  const memberAddWrap = document.getElementById("member-add-wrap");
  const memberAddSelect = document.getElementById("member-add-select");

  memberWrap.innerHTML = "";
  membersDetail.innerHTML = "";
  memberAddSelect.innerHTML = "";

  if (!state.activeGroup) {
    activeName.textContent = "Sin grupo";
    activeDescription.textContent = "Crea un grupo para empezar.";
    hostLine.textContent = "";
    deleteSummary.textContent = "Todavia no hay un grupo activo.";
    memberAddWrap.classList.add("hidden");
    return;
  }

  activeName.textContent = state.activeGroup.name;
  activeDescription.textContent = state.activeGroup.description || "Este grupo aun no tiene descripcion.";
  hostLine.textContent = `Anfitrion: ${state.activeGroup.host.username}`;

  state.activeGroup.members.forEach((member) => {
    const chip = document.createElement("div");
    chip.className = "member-chip";
    chip.innerHTML = `
      <strong>${escapeHtml(member.username)}</strong>
      <span class="muted small">${escapeHtml(member.email)}</span>
      ${member.id === state.activeGroup.host.id ? '<span class="tag">Anfitrion</span>' : ""}
    `;
    memberWrap.appendChild(chip.cloneNode(true));
    membersDetail.appendChild(chip);
  });

  const deleteVote = state.activeGroup.active_group_delete_vote;
  if (deleteVote) {
    deleteSummary.textContent = `${deleteVote.vote_count}/${deleteVote.threshold} votos para eliminar el grupo (${deleteVote.mode}).`;
  } else {
    deleteSummary.textContent = "No hay votacion activa para eliminar el grupo.";
  }

  const presentIds = new Set(state.activeGroup.members.map((member) => member.id));
  const availableUsers = state.users.filter((user) => !presentIds.has(user.id));
  if (!availableUsers.length) {
    memberAddWrap.classList.add("hidden");
    return;
  }

  memberAddWrap.classList.remove("hidden");
  availableUsers.forEach((user) => {
    const option = document.createElement("option");
    option.value = String(user.id);
    option.textContent = `${user.username} (${user.email})`;
    memberAddSelect.appendChild(option);
  });
}

function renderExpenseForm() {
  const payerSelect = document.getElementById("expense-payer");
  const participantList = document.getElementById("participant-list");
  const settlementFrom = document.getElementById("settlement-from-user");
  const settlementTo = document.getElementById("settlement-to-user");
  const proposalPayer = document.getElementById("proposal-payer-user");
  const ratingUser = document.getElementById("rating-user");

  payerSelect.innerHTML = "";
  participantList.innerHTML = "";
  settlementFrom.innerHTML = "";
  settlementTo.innerHTML = "";
  proposalPayer.innerHTML = '<option value="">Quien pagara?</option>';
  ratingUser.innerHTML = "";

  if (!state.activeGroup) {
    payerSelect.innerHTML = '<option value="">Primero crea un grupo</option>';
    settlementFrom.innerHTML = '<option value="">Sin grupo</option>';
    settlementTo.innerHTML = '<option value="">Sin grupo</option>';
    ratingUser.innerHTML = '<option value="">Sin grupo</option>';
    return;
  }

  state.activeGroup.members.forEach((member) => {
    const option = document.createElement("option");
    option.value = String(member.id);
    option.textContent = member.username;
    payerSelect.appendChild(option);

    const label = document.createElement("label");
    label.innerHTML = `
      <input type="checkbox" name="participantIds" value="${member.id}" checked />
      <span>${escapeHtml(member.username)}</span>
    `;
    participantList.appendChild(label);

    settlementFrom.appendChild(option.cloneNode(true));
    settlementTo.appendChild(option.cloneNode(true));
    proposalPayer.appendChild(option.cloneNode(true));

    if (member.id !== state.currentUser.id) {
      ratingUser.appendChild(option.cloneNode(true));
    }
  });
}

function renderExpenses() {
  const wrap = document.getElementById("expense-list");
  wrap.innerHTML = "";

  if (!state.expenses.length) {
    wrap.innerHTML = '<div class="table-row muted small">Todavia no hay gastos registrados.</div>';
    return;
  }

  state.expenses.forEach((expense) => {
    const row = document.createElement("div");
    row.className = "table-row";
    const participants = expense.participants
      .map((participant) => `${participant.username} (${money(participant.share_amount)})`)
      .join(", ");
    const deleteVoteText = expense.delete_vote
      ? `${expense.delete_vote.vote_count}/${expense.delete_vote.threshold} votos para eliminar`
      : "Sin votacion de eliminacion";
    row.innerHTML = `
      <strong>${escapeHtml(expense.description)}</strong>
      <span class="muted small">Pago ${escapeHtml(expense.payer.username)} | ${money(expense.amount)}</span>
      <span class="muted small">Se divide entre: ${escapeHtml(participants)}</span>
      <span class="muted small">${escapeHtml(deleteVoteText)}</span>
    `;
    const actions = document.createElement("div");
    actions.className = "action-row";
    const voteButton = document.createElement("button");
    voteButton.className = "ghost-btn mini-btn";
    voteButton.type = "button";
    voteButton.textContent = "Votar eliminar deuda";
    voteButton.addEventListener("click", () => handleVoteDeleteExpense(expense.id));
    actions.appendChild(voteButton);
    row.appendChild(actions);
    wrap.appendChild(row);
  });
}

function renderBalances() {
  const balancesEl = document.getElementById("balances-list");
  const settlementsEl = document.getElementById("settlements-list");
  const historyEl = document.getElementById("settlement-history");
  balancesEl.innerHTML = "";
  settlementsEl.innerHTML = "";
  historyEl.innerHTML = "";

  if (!state.balances) {
    balancesEl.innerHTML = '<div class="balance-item muted small">No hay balances todavia.</div>';
    settlementsEl.innerHTML = '<div class="settlement-item muted small">Sin datos.</div>';
  } else {
    state.balances.balances.forEach((entry) => {
      const div = document.createElement("div");
      div.className = "balance-item";
      div.innerHTML = `
        <strong>${escapeHtml(entry.user.username)}</strong>
        <span class="muted small">Pago ${money(entry.paid)} | Debe ${money(entry.owed)} | Liquido ${money(
          entry.settled_out
        )} | Neto ${money(entry.net)}</span>
      `;
      balancesEl.appendChild(div);
    });

    if (!state.balances.settlements.length) {
      settlementsEl.innerHTML = '<div class="settlement-item muted small">Todo esta balanceado.</div>';
    } else {
      state.balances.settlements.forEach((settlement) => {
        const div = document.createElement("div");
        div.className = "settlement-item";
        div.innerHTML = `
          <strong>${escapeHtml(settlement.from_user.username)} -> ${escapeHtml(settlement.to_user.username)}</strong>
          <span class="muted small">${money(settlement.amount)}</span>
        `;
        settlementsEl.appendChild(div);
      });
    }
  }

  if (!state.settlements.length) {
    historyEl.innerHTML = '<div class="table-row muted small">No hay liquidaciones manuales.</div>';
    return;
  }

  state.settlements.forEach((settlement) => {
    const row = document.createElement("div");
    row.className = "table-row";
    row.innerHTML = `
      <strong>${escapeHtml(settlement.from_user.username)} pago a ${escapeHtml(settlement.to_user.username)}</strong>
      <span class="muted small">${money(settlement.amount)} | ${escapeHtml(settlement.notes || "Sin notas")}</span>
    `;
    historyEl.appendChild(row);
  });
}

function renderFeed() {
  const wrap = document.getElementById("feed-list");
  wrap.innerHTML = "";

  if (!state.feed.length) {
    wrap.innerHTML = '<div class="feed-item muted small">Todavia no hay actividad.</div>';
    return;
  }

  state.feed.forEach((event) => {
    const item = document.createElement("div");
    item.className = "feed-item";
    item.innerHTML = `
      <strong>${formatDate(event.created_at)}</strong>
      <div>${escapeHtml(event.message)}</div>
    `;
    wrap.appendChild(item);
  });
}

function renderFeedPreview() {
  const wrap = document.getElementById("feed-preview");
  wrap.innerHTML = "";

  const previewItems = state.feed.slice(0, 5);
  if (!previewItems.length) {
    wrap.innerHTML = '<div class="feed-item muted small">Todavia no hay actividad.</div>';
    return;
  }

  previewItems.forEach((event) => {
    const item = document.createElement("div");
    item.className = "feed-item";
    item.innerHTML = `
      <strong>${formatDate(event.created_at)}</strong>
      <div>${escapeHtml(event.message)}</div>
    `;
    wrap.appendChild(item);
  });
}

function renderRecentExpenses() {
  const wrap = document.getElementById("recent-expenses");
  wrap.innerHTML = "";

  const items = state.summary?.recent_expenses || [];
  if (!items.length) {
    wrap.innerHTML = '<div class="table-row muted small">Todavia no hay gastos recientes.</div>';
    return;
  }

  items.forEach((expense) => {
    const row = document.createElement("div");
    row.className = "table-row";
    row.innerHTML = `
      <strong>${escapeHtml(expense.description)}</strong>
      <span class="muted small">${escapeHtml(expense.group_name)} | Pago ${escapeHtml(
        expense.payer_name
      )} | ${money(expense.amount)} | ${formatDate(expense.created_at)}</span>
    `;
    wrap.appendChild(row);
  });
}

function renderInviteOptions() {
  const inviteSelect = document.getElementById("group-invite-list");
  inviteSelect.innerHTML = "";
  state.users
    .filter((user) => user.id !== state.currentUser.id)
    .forEach((user) => {
      const option = document.createElement("option");
      option.value = String(user.id);
      option.textContent = `${user.username} (${user.email})`;
      inviteSelect.appendChild(option);
    });
}

function renderSelectedProposal() {
  const wrap = document.getElementById("selected-proposal-card");
  wrap.innerHTML = "";

  const selectedProposal = state.stats?.selected_proposal || state.proposals.find((proposal) => proposal.status === "selected");
  if (!selectedProposal) {
    wrap.innerHTML = '<div class="table-row muted small">Todavia no hay propuesta elegida.</div>';
    return;
  }

  wrap.innerHTML = `
    <div class="table-row">
      <strong>${escapeHtml(selectedProposal.title)}</strong>
      <span class="muted small">${escapeHtml(selectedProposal.activity_type)} | ${money(selectedProposal.total_amount)}</span>
      <span class="muted small">Proveedor: ${escapeHtml(selectedProposal.provider_name || "Sin proveedor")}</span>
      <span class="muted small">Confirmacion: ${escapeHtml(selectedProposal.confirmation_status)}</span>
    </div>
  `;
}

function renderStats() {
  renderStatRows("stats-spend", state.stats?.spend_by_user || [], "amount", money);
  renderStatRows("stats-proposals", state.stats?.proposal_votes || [], "votes", (value) => `${value} votos`);
  renderStatRows("stats-activities", state.stats?.activity_breakdown || [], "count", (value) => `${value} propuestas`);

  const topRated = document.getElementById("stats-top-rated");
  topRated.innerHTML = "";
  const rows = state.stats?.top_rated_users || [];
  if (!rows.length) {
    topRated.innerHTML = '<div class="table-row muted small">Todavia no hay calificaciones.</div>';
    return;
  }

  rows.forEach((row) => {
    const item = document.createElement("div");
    item.className = "table-row";
    item.innerHTML = `
      <strong>${escapeHtml(row.user.username)}</strong>
      <span class="muted small">${row.badge_title} | ${row.average_score}/5 con ${row.rating_count} calificaciones</span>
    `;
    topRated.appendChild(item);
  });
}

function renderStatRows(elementId, rows, field, formatter) {
  const wrap = document.getElementById(elementId);
  wrap.innerHTML = "";
  if (!rows.length) {
    wrap.innerHTML = '<div class="stat-row muted small">Todavia no hay datos.</div>';
    return;
  }

  const maxValue = Math.max(...rows.map((row) => row[field] || 0), 1);
  rows.forEach((row) => {
    const ratio = ((row[field] || 0) / maxValue) * 100;
    const item = document.createElement("div");
    item.className = "stat-row";
    item.innerHTML = `
      <div class="stat-meta">
        <strong>${escapeHtml(row.label)}</strong>
        <span class="muted small">${escapeHtml(formatter(row[field] || 0))}</span>
      </div>
      <div class="stat-bar"><div class="stat-fill" style="width:${ratio}%"></div></div>
    `;
    wrap.appendChild(item);
  });
}

function renderProposals() {
  const wrap = document.getElementById("proposal-list");
  wrap.innerHTML = "";

  if (!state.proposals.length) {
    wrap.innerHTML = '<div class="table-row muted small">Todavia no hay propuestas para votar.</div>';
    return;
  }

  state.proposals.forEach((proposal) => {
    const row = document.createElement("div");
    row.className = "table-row proposal-card";
    const payerText = proposal.payer_user ? proposal.payer_user.username : "Por definir";
    const votedByMe = proposal.voters.some((user) => user.id === state.currentUser.id);
    row.innerHTML = `
      <div class="section-head">
        <strong>${escapeHtml(proposal.title)}</strong>
        <span class="tag">${escapeHtml(proposal.status === "selected" ? "Elegida" : proposal.activity_type)}</span>
      </div>
      <span class="muted small">${escapeHtml(proposal.details || "Sin detalles extra")}</span>
      <div class="proposal-meta">
        <span class="muted small">Disponibilidad: ${escapeHtml(proposal.availability_text || "Sin definir")}</span>
        <span class="muted small">Proveedor: ${escapeHtml(proposal.provider_name || "Sin proveedor")}</span>
        <span class="muted small">A pagar por: ${escapeHtml(payerText)}</span>
        <span class="muted small">Antes de: ${escapeHtml(proposal.payment_due_date || "Sin fecha")}</span>
        <span class="muted small">Para fecha: ${escapeHtml(proposal.scheduled_for_date || "Sin fecha")}</span>
        <span class="muted small">Metodo: ${escapeHtml(proposal.payment_method || "Sin definir")}</span>
        <span class="muted small">Confirmacion: ${escapeHtml(proposal.confirmation_status)}</span>
        <span class="muted small">Total: ${money(proposal.total_amount)}</span>
      </div>
      <span class="muted small">Votos: ${proposal.vote_count}/${proposal.vote_threshold}</span>
    `;

    const actions = document.createElement("div");
    actions.className = "action-row";
    const voteButton = document.createElement("button");
    voteButton.type = "button";
    voteButton.className = "ghost-btn mini-btn";
    voteButton.textContent = votedByMe ? "Ya votaste" : "Votar";
    voteButton.disabled = votedByMe;
    voteButton.addEventListener("click", () => handleVoteProposal(proposal.id));
    actions.appendChild(voteButton);

    if (state.activeGroup && state.activeGroup.host.id === state.currentUser.id) {
      const selectButton = document.createElement("button");
      selectButton.type = "button";
      selectButton.className = "primary-btn mini-btn";
      selectButton.textContent = proposal.status === "selected" ? "Ya elegida" : "Elegir";
      selectButton.disabled = proposal.status === "selected";
      selectButton.addEventListener("click", () => handleSelectProposal(proposal.id));
      actions.appendChild(selectButton);
    }

    row.appendChild(actions);
    wrap.appendChild(row);
  });
}

function renderRatings() {
  const leaderboard = document.getElementById("rating-leaderboard");
  const history = document.getElementById("rating-history");
  leaderboard.innerHTML = "";
  history.innerHTML = "";

  if (!state.ratings.leaderboard.length) {
    leaderboard.innerHTML = '<div class="table-row muted small">Todavia no hay ranking.</div>';
  } else {
    state.ratings.leaderboard.forEach((entry) => {
      const row = document.createElement("div");
      row.className = "table-row";
      row.innerHTML = `
        <strong>${escapeHtml(entry.user.username)}</strong>
        <span class="muted small">${escapeHtml(entry.badge_title)} | ${entry.average_score}/5 con ${entry.rating_count} votos</span>
        <span class="muted small">${escapeHtml((entry.custom_titles || []).join(", ") || "Sin titulos custom")}</span>
      `;
      leaderboard.appendChild(row);
    });
  }

  if (!state.ratings.ratings.length) {
    history.innerHTML = '<div class="table-row muted small">Todavia no hay calificaciones registradas.</div>';
  } else {
    state.ratings.ratings.forEach((rating) => {
      const row = document.createElement("div");
      row.className = "table-row";
      row.innerHTML = `
        <strong>${escapeHtml(rating.rated_user.username)} recibio '${escapeHtml(rating.title)}'</strong>
        <span class="muted small">${escapeHtml(rating.rater.username)} dio ${rating.score}/5 | ${escapeHtml(
          rating.comment || "Sin comentario"
        )}</span>
      `;
      history.appendChild(row);
    });
  }
}

function renderViewVisibility() {
  document.querySelectorAll(".view-section").forEach((section) => {
    section.classList.add("hidden");
  });
  const activeSection = document.getElementById(`view-${state.activeView}`);
  if (activeSection) {
    activeSection.classList.remove("hidden");
  }
}

function money(amount) {
  return new Intl.NumberFormat("es-MX", {
    style: "currency",
    currency: "MXN",
  }).format(amount || 0);
}

function formatDate(value) {
  return new Date(value).toLocaleString("es-MX", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function showToast(message, type) {
  toastEl.textContent = message;
  toastEl.className = `toast ${type}`;
  setTimeout(() => {
    toastEl.className = "toast hidden";
  }, 3200);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
