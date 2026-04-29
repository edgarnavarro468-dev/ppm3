const API_BASE = "";

const VIEW_META = {
  dashboard: {
    title: "Ten claro que esta pasando y que sigue.",
    subtitle: "Empieza aqui para ver el estado del grupo y entrar rapido a la accion correcta.",
  },
  groups: {
    title: "Ordena al grupo antes de mover dinero.",
    subtitle: "Gestiona miembros, anfitrion y decisiones importantes del grupo.",
  },
  expenses: {
    title: "Registrar un gasto debe tomar segundos.",
    subtitle: "Guarda quien pago, cuanto fue y entre quienes se reparte.",
  },
  balances: {
    title: "Que todos sepan quien debe y quien ya pago.",
    subtitle: "Revisa saldos y marca liquidaciones manuales cuando el pago ya se hizo.",
  },
  feed: {
    title: "Todo lo importante queda trazado.",
    subtitle: "Cada gasto, voto, liquidacion o propuesta queda visible para el grupo.",
  },
  stats: {
    title: "Las decisiones tambien se leen en datos.",
    subtitle: "Revisa gasto por usuario, votos por propuesta y actividad del grupo.",
  },
  proposals: {
    title: "Conviertan ideas en planes claros.",
    subtitle: "Planea comida, actividad o lugar con datos suficientes para votar sin dudas.",
  },
  community: {
    title: "La confianza del grupo tambien importa.",
    subtitle: "Califiquen usuarios y dejen memoria de quien si cumple.",
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
  userSearchResults: [],
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
const profileForm = document.getElementById("profile-form");
const profileSearchInput = document.getElementById("profile-search-input");
const currentUserAvatar = document.getElementById("current-user-avatar");
const currentUserAvatarFallback = document.getElementById("current-user-avatar-fallback");
const currentUserPhone = document.getElementById("current-user-phone");
const profileAvatarPreview = document.getElementById("profile-avatar-preview");
const profileAvatarFallback = document.getElementById("profile-avatar-fallback");
const profileDisplayName = document.getElementById("profile-display-name");
const profileDisplayEmail = document.getElementById("profile-display-email");
const profileDisplayPhone = document.getElementById("profile-display-phone");

document.getElementById("show-login").addEventListener("click", () => toggleAuthMode("login"));
document.getElementById("show-register").addEventListener("click", () => toggleAuthMode("register"));
document.getElementById("logout-btn").addEventListener("click", logout);
document.getElementById("refresh-groups-btn").addEventListener("click", bootstrapApp);
document.getElementById("reload-all-btn").addEventListener("click", bootstrapApp);
document.getElementById("journey-action-btn").addEventListener("click", handleJourneyAction);
document.getElementById("add-member-btn").addEventListener("click", handleAddMember);
document.getElementById("group-delete-vote-btn").addEventListener("click", handleGroupDeleteVote);

loginForm.addEventListener("submit", handleLogin);
registerForm.addEventListener("submit", handleRegister);
groupForm.addEventListener("submit", handleCreateGroup);
expenseForm.addEventListener("submit", handleCreateExpense);
manualSettlementForm.addEventListener("submit", handleCreateSettlement);
proposalForm.addEventListener("submit", handleCreateProposal);
ratingForm.addEventListener("submit", handleCreateRating);
profileForm?.addEventListener("submit", handleUpdateProfile);
profileForm?.addEventListener("input", syncProfilePreviewFromForm);
profileSearchInput?.addEventListener("input", renderUserSearchResults);

document.querySelectorAll(".nav-btn").forEach((button) => {
  button.addEventListener("click", () => setActiveView(button.dataset.view));
});

document.querySelectorAll(".quick-action-btn, .shortcut-card").forEach((button) => {
  button.addEventListener("click", () => setActiveView(button.dataset.view));
});

toggleAuthMode("login");
resetAuthTimers();
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

function resetAuthTimers() {
  const startedAt = Date.now() / 1000;
  loginForm.dataset.startedAt = String(startedAt);
  registerForm.dataset.startedAt = String(startedAt);
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
  resetAuthTimers();
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
        website: formData.get("website") || "",
        form_started_at: Number(loginForm.dataset.startedAt || 0),
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
        first_name: formData.get("firstName"),
        last_name: formData.get("lastName"),
        email: formData.get("email"),
        phone_number: formData.get("phoneNumber"),
        avatar_url: formData.get("avatarUrl"),
        password: formData.get("password"),
        website: formData.get("website") || "",
        form_started_at: Number(registerForm.dataset.startedAt || 0),
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
  state.userSearchResults = [];
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
    state.userSearchResults = users.filter((user) => user.id !== state.currentUser.id).slice(0, 8);

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
    showAutomaticReminders();
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
        ends_at: formData.get("endsAt"),
        auto_close_action: formData.get("autoCloseAction"),
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
        provider_url: formData.get("providerUrl"),
        payer_user_id: payerValue ? Number(payerValue) : null,
        payment_due_date: formData.get("paymentDueDate"),
        scheduled_for_date: formData.get("scheduledForDate"),
        vote_deadline: formData.get("voteDeadline"),
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

async function handleConfirmSettlement(settlementId) {
  try {
    await api(`/settlements/${settlementId}/confirm`, {
      method: "POST",
      body: JSON.stringify({ actor_id: state.currentUser.id }),
    });
    showToast("Pago confirmado como recibido.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleUpdateProfile(event) {
  event.preventDefault();
  const formData = new FormData(profileForm);
  try {
    const result = await api(`/users/${state.currentUser.id}`, {
      method: "PATCH",
      body: JSON.stringify({
        username: formData.get("username"),
        first_name: formData.get("firstName"),
        last_name: formData.get("lastName"),
        phone_number: formData.get("phoneNumber"),
        avatar_url: formData.get("avatarUrl"),
      }),
    });
    state.currentUser = result.user;
    persistState();
    showToast("Perfil actualizado.", "success");
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

  document.getElementById("current-user-name").textContent = userLabel(state.currentUser);
  document.getElementById("current-user-email").textContent = state.currentUser.email;
  currentUserPhone.textContent = state.currentUser.phone_number ? `Tel: ${state.currentUser.phone_number}` : "Sin telefono guardado";
  profileDisplayName.textContent = userLabel(state.currentUser);
  profileDisplayEmail.textContent = state.currentUser.email;
  profileDisplayPhone.textContent = state.currentUser.phone_number || "Agrega tu telefono para identificarte mejor.";
  syncAvatar(currentUserAvatar, currentUserAvatarFallback, state.currentUser.avatar_url, initials(state.currentUser));
  syncAvatar(profileAvatarPreview, profileAvatarFallback, state.currentUser.avatar_url, initials(state.currentUser));
  if (profileForm) {
    profileForm.elements.username.value = state.currentUser.username || "";
    profileForm.elements.firstName.value = state.currentUser.first_name || "";
    profileForm.elements.lastName.value = state.currentUser.last_name || "";
    profileForm.elements.phoneNumber.value = state.currentUser.phone_number || "";
    profileForm.elements.avatarUrl.value = state.currentUser.avatar_url || "";
    syncProfilePreviewFromForm();
  }

  renderHero();
  renderNav();
  renderMetrics();
  renderJourney();
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
  renderUserSearchResults();
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
    group_count: 0,
  };
  document.getElementById("metric-total-expenses").textContent = money(summary.total_expenses);
  document.getElementById("metric-total-paid").textContent = money(summary.total_paid);
  document.getElementById("metric-net-balance").textContent = money(summary.net_balance);
  document.getElementById("metric-proposal-count").textContent = String(summary.group_count || 0);
}

function renderJourney() {
  const titleEl = document.getElementById("journey-status-title");
  const copyEl = document.getElementById("journey-status-copy");
  const nextStepEl = document.getElementById("journey-next-step");
  const actionBtn = document.getElementById("journey-action-btn");
  const checklist = document.getElementById("setup-checklist");

  const groupReady = Boolean(state.activeGroup);
  const hasExpenses = state.expenses.length > 0;
  const hasProposals = state.proposals.length > 0;
  const hasSettlements = state.settlements.length > 0;

  let statusTitle = "Todavia no hay grupo activo";
  let statusCopy = "Crea un grupo para empezar a registrar planes, gastos y decisiones.";
  let nextStep = "Crear o elegir un grupo";
  let actionView = "groups";

  if (groupReady && !hasExpenses) {
    statusTitle = "El grupo ya esta listo para operar";
    statusCopy = "El siguiente paso natural es capturar el primer gasto real para que aparezcan saldos.";
    nextStep = "Registrar el primer gasto";
    actionView = "expenses";
  } else if (groupReady && hasExpenses && !hasProposals) {
    statusTitle = "Ya hay movimiento economico";
    statusCopy = "Ahora conviene proponer un plan para validar la parte social y de votacion.";
    nextStep = "Crear una propuesta";
    actionView = "proposals";
  } else if (groupReady && hasExpenses && hasProposals && !hasSettlements) {
    statusTitle = "El grupo ya usa gastos y planes";
    statusCopy = "Revisen saldos para confirmar si alguien ya puede liquidar o cerrar cuentas.";
    nextStep = "Revisar saldos";
    actionView = "balances";
  } else if (groupReady) {
    statusTitle = "El flujo principal ya esta cubierto";
    statusCopy = "Ya probaron grupo, gastos, planes y liquidaciones. Ahora vale la pena revisar actividad y reputacion.";
    nextStep = "Ver actividad del grupo";
    actionView = "feed";
  }

  titleEl.textContent = statusTitle;
  copyEl.textContent = statusCopy;
  nextStepEl.textContent = nextStep;
  actionBtn.dataset.view = actionView;

  const checklistItems = [
    {
      done: groupReady,
      title: "Grupo activo",
      copy: groupReady
        ? `Trabajando en ${state.activeGroup.name}.`
        : "Sin grupo todavia. Crea uno o selecciona uno para continuar.",
    },
    {
      done: hasExpenses,
      title: "Primer gasto registrado",
      copy: hasExpenses
        ? `${state.expenses.length} gasto(s) cargado(s) en este grupo.`
        : "Cuando registren el primer gasto, apareceran deudas y saldos.",
    },
    {
      done: hasProposals,
      title: "Plan o propuesta creada",
      copy: hasProposals
        ? `${state.proposals.length} propuesta(s) lista(s) para votar o elegir.`
        : "Sube una idea clara para que el grupo pueda votar sin friccion.",
    },
    {
      done: hasSettlements || Boolean(state.balances?.settlements?.length),
      title: "Cierre o liquidacion revisada",
      copy:
        hasSettlements || Boolean(state.balances?.settlements?.length)
          ? "Ya existe historial o sugerencias de liquidacion."
          : "Todavia no hay liquidaciones; usa la vista de saldos para cerrar cuentas.",
    },
  ];

  checklist.innerHTML = checklistItems
    .map(
      (item) => `
        <div class="check-item ${item.done ? "done" : ""}">
          <span class="check-badge">${item.done ? "OK" : "..."}</span>
          <div>
            <strong>${escapeHtml(item.title)}</strong>
            <div class="muted small">${escapeHtml(item.copy)}</div>
          </div>
        </div>
      `
    )
    .join("");
}

function handleJourneyAction() {
  const targetView = document.getElementById("journey-action-btn").dataset.view || "groups";
  setActiveView(targetView);
}

function renderGroups() {
  const wrap = document.getElementById("group-list");
  wrap.innerHTML = "";

  if (!state.groups.length) {
    wrap.innerHTML = '<div class="group-item muted small">Todavia no hay grupos. Usa el formulario de abajo para crear el primero.</div>';
    return;
  }

  state.groups.forEach((group) => {
    const item = document.createElement("article");
    item.className = `group-item ${group.id === state.activeGroupId ? "active" : ""}`;
    const paymentText =
      group.payment_status === "pagado"
        ? `${group.settled_member_count} al dia`
        : group.payment_status === "pendientes"
          ? `${group.pending_member_count} pendientes`
          : "Sin movimientos";
    item.innerHTML = `
      <button type="button">
        <strong>${escapeHtml(group.name)}</strong>
        <div class="muted small">${escapeHtml(group.description || "Sin descripcion")}</div>
        <div class="muted small">${escapeHtml(group.status === "suspended" ? "Suspendido" : "Activo")} | ${escapeHtml(paymentText)}</div>
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
    activeDescription.textContent = "Crea un grupo o elige uno existente para desbloquear gastos, planes y saldos.";
    hostLine.textContent = "";
    deleteSummary.textContent = "Todavia no hay un grupo activo.";
    memberAddWrap.classList.add("hidden");
    return;
  }

  activeName.textContent = state.activeGroup.name;
  activeDescription.textContent = state.activeGroup.description || "Este grupo aun no tiene descripcion.";
  hostLine.textContent = `Anfitrion: ${state.activeGroup.host.username} | Estado: ${
    state.activeGroup.status === "suspended" ? "Suspendido" : "Activo"
  }${state.activeGroup.ends_at ? ` | Cierra: ${state.activeGroup.ends_at}` : ""}`;

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
    payerSelect.innerHTML = '<option value="">Primero crea o elige un grupo</option>';
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
    wrap.innerHTML = '<div class="table-row muted small">Todavia no hay gastos registrados. Captura uno para que el grupo empiece a generar saldos.</div>';
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
    balancesEl.innerHTML = '<div class="balance-item muted small">No hay balances todavia. Apareceran despues del primer gasto.</div>';
    settlementsEl.innerHTML = '<div class="settlement-item muted small">Sin datos por ahora.</div>';
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
      <span class="muted small">${settlement.received_confirmed ? "Pago recibido confirmado" : "Pendiente por confirmar"}</span>
    `;
    if (!settlement.received_confirmed && settlement.to_user.id === state.currentUser.id) {
      const button = document.createElement("button");
      button.className = "ghost-btn mini-btn";
      button.type = "button";
      button.textContent = "Confirmar que ya llego";
      button.addEventListener("click", () => handleConfirmSettlement(settlement.id));
      row.appendChild(button);
    }
    historyEl.appendChild(row);
  });
}

function renderFeed() {
  const wrap = document.getElementById("feed-list");
  wrap.innerHTML = "";

  if (!state.feed.length) {
    wrap.innerHTML = '<div class="feed-item muted small">Todavia no hay actividad. Aqui veran el historial del grupo en cuanto empiecen a usarlo.</div>';
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
    wrap.innerHTML = '<div class="feed-item muted small">Todavia no hay actividad reciente.</div>';
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
      option.textContent = `${user.display_name || user.username} (${user.email})`;
      inviteSelect.appendChild(option);
    });
}

function renderSelectedProposal() {
  const wrap = document.getElementById("selected-proposal-card");
  wrap.innerHTML = "";

  const selectedProposal = state.stats?.selected_proposal || state.proposals.find((proposal) => proposal.status === "selected");
  if (!selectedProposal) {
    wrap.innerHTML = '<div class="table-row muted small">Todavia no hay propuesta elegida. Primero crean una idea y luego la votan en la vista de Planes.</div>';
    return;
  }

  wrap.innerHTML = `
    <div class="table-row">
      <strong>${escapeHtml(selectedProposal.title)}</strong>
      <span class="muted small">${escapeHtml(selectedProposal.activity_type)} | ${money(selectedProposal.total_amount)}</span>
      <span class="muted small">Proveedor: ${escapeHtml(selectedProposal.provider_name || "Sin proveedor")}</span>
      ${
        selectedProposal.provider_url
          ? `<a class="muted small" href="${escapeHtml(selectedProposal.provider_url)}" target="_blank" rel="noopener noreferrer">Abrir sitio del proveedor</a>`
          : ""
      }
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
      <span class="star-row">${stars(row.average_score)}</span>
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
    wrap.innerHTML = '<div class="table-row muted small">Todavia no hay propuestas para votar. Crea una idea clara para que el grupo compare opciones.</div>';
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
        ${
          proposal.provider_url
            ? `<a class="muted small" href="${escapeHtml(proposal.provider_url)}" target="_blank" rel="noopener noreferrer">Ver sitio</a>`
            : '<span class="muted small">Sin URL del proveedor</span>'
        }
        <span class="muted small">A pagar por: ${escapeHtml(payerText)}</span>
        <span class="muted small">Antes de: ${escapeHtml(proposal.payment_due_date || "Sin fecha")}</span>
        <span class="muted small">Para fecha: ${escapeHtml(proposal.scheduled_for_date || "Sin fecha")}</span>
        <span class="muted small">Vota antes de: ${escapeHtml(proposal.vote_deadline || "Sin limite")}</span>
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
    voteButton.disabled = votedByMe || isVoteClosed(proposal.vote_deadline);
    voteButton.addEventListener("click", () => handleVoteProposal(proposal.id));
    actions.appendChild(voteButton);

    if (proposal.scheduled_for_date) {
      const calendarLink = document.createElement("a");
      calendarLink.className = "ghost-btn mini-btn";
      calendarLink.href = buildCalendarUrl(proposal);
      calendarLink.target = "_blank";
      calendarLink.rel = "noopener noreferrer";
      calendarLink.textContent = "Agregar al calendario";
      actions.appendChild(calendarLink);
    }

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
        <span class="star-row">${stars(entry.average_score)}</span>
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
        <span class="star-row">${stars(rating.score)}</span>
        <span class="muted small">${escapeHtml(rating.rater.username)} dio ${rating.score}/5 | ${escapeHtml(
          rating.comment || "Sin comentario"
        )}</span>
      `;
      history.appendChild(row);
    });
  }
}

function renderUserSearchResults() {
  const wrap = document.getElementById("profile-search-results");
  if (!wrap) {
    return;
  }

  const query = String(profileSearchInput?.value || "").trim().toLowerCase();
  const results = state.users.filter((user) => {
    if (user.id === state.currentUser.id) {
      return false;
    }
    if (!query) {
      return true;
    }
    const haystack = [
      user.username,
      user.display_name,
      user.first_name,
      user.last_name,
      user.email,
      user.phone_number,
    ]
      .filter(Boolean)
      .join(" ")
      .toLowerCase();
    return haystack.includes(query);
  });

  wrap.innerHTML = "";
  if (!results.length) {
    wrap.innerHTML = '<div class="table-row muted small">No encontramos usuarios con esa busqueda.</div>';
    return;
  }

  results.slice(0, 12).forEach((user) => {
    const row = document.createElement("div");
    row.className = "table-row";
    row.innerHTML = `
      <strong>${escapeHtml(user.display_name || user.username)}</strong>
      <span class="muted small">@${escapeHtml(user.username)} | ${escapeHtml(user.phone_number || user.email)}</span>
    `;
    wrap.appendChild(row);
  });
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

function userLabel(user) {
  return user.display_name || user.full_name || user.username;
}

function initials(user) {
  const source = userLabel(user).trim();
  if (!source) {
    return "P";
  }
  const parts = source.split(/\s+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0].toUpperCase()).join("") || "P";
}

function syncAvatar(imageEl, fallbackEl, url, fallbackText) {
  if (!imageEl || !fallbackEl) {
    return;
  }
  const hasUrl = Boolean(String(url || "").trim());
  fallbackEl.textContent = fallbackText;
  imageEl.classList.toggle("hidden", !hasUrl);
  fallbackEl.classList.toggle("hidden", hasUrl);
  if (hasUrl) {
    imageEl.src = String(url).trim();
  } else {
    imageEl.removeAttribute("src");
  }
}

function syncProfilePreviewFromForm() {
  if (!profileForm) {
    return;
  }
  const username = String(profileForm.elements.username.value || "").trim();
  const firstName = String(profileForm.elements.firstName.value || "").trim();
  const lastName = String(profileForm.elements.lastName.value || "").trim();
  const phone = String(profileForm.elements.phoneNumber.value || "").trim();
  const avatarUrl = String(profileForm.elements.avatarUrl.value || "").trim();
  const previewUser = {
    username: username || state.currentUser?.username || "perfil",
    display_name: [firstName, lastName].filter(Boolean).join(" ") || username || state.currentUser?.display_name || "",
    avatar_url: avatarUrl,
  };
  profileDisplayName.textContent = userLabel(previewUser);
  profileDisplayEmail.textContent = state.currentUser?.email || "";
  profileDisplayPhone.textContent = phone || "Agrega tu telefono para identificarte mejor.";
  syncAvatar(profileAvatarPreview, profileAvatarFallback, avatarUrl, initials(previewUser));
}

function formatDate(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "Fecha no disponible";
  }
  return date.toLocaleString("es-MX", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function stars(score) {
  const rounded = Math.max(1, Math.min(5, Math.round(Number(score) || 0)));
  return "★".repeat(rounded) + "☆".repeat(5 - rounded);
}

function isVoteClosed(value) {
  if (!value) {
    return false;
  }
  const date = new Date(value);
  return !Number.isNaN(date.getTime()) && date < new Date();
}

function buildCalendarUrl(proposal) {
  const date = new Date(proposal.scheduled_for_date);
  const end = new Date(date);
  end.setHours(end.getHours() + 2);
  const startStamp = date.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
  const endStamp = end.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
  const params = new URLSearchParams({
    action: "TEMPLATE",
    text: proposal.title,
    details: `${proposal.details || ""}\n${proposal.provider_url || ""}`.trim(),
    dates: `${startStamp}/${endStamp}`,
  });
  return `https://calendar.google.com/calendar/render?${params.toString()}`;
}

function showAutomaticReminders() {
  if (!state.activeGroup) {
    return;
  }

  const closingProposal = state.proposals.find((proposal) => {
    if (!proposal.vote_deadline || proposal.voters.some((user) => user.id === state.currentUser.id)) {
      return false;
    }
    const deadline = new Date(proposal.vote_deadline);
    const now = new Date();
    return !Number.isNaN(deadline.getTime()) && deadline > now && deadline.getTime() - now.getTime() < 24 * 60 * 60 * 1000;
  });

  if (closingProposal) {
    showToast(`Recuerdo: la votacion de '${closingProposal.title}' cierra pronto.`, "success");
  }

  if (state.balances?.settlements?.length) {
    const due = state.balances.settlements.find((item) => item.from_user.id === state.currentUser.id);
    if (due) {
      showToast(`Recuerdo: tienes un pago pendiente hacia ${due.to_user.username}.`, "success");
    }
  }
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
