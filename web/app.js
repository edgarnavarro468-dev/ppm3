const API_BASE = "";
const APP_VIEWS = new Set(["groups", "expenses", "activity", "account"]);
const GROUP_TABS = new Set(["expenses", "balances"]);

const state = {
  currentUser: loadJson("ppm-current-user"),
  activeView: sanitizeView(localStorage.getItem("ppm-active-view")),
  activeGroupId: loadNumber("ppm-active-group-id"),
  groupDetailTab: sanitizeGroupTab(localStorage.getItem("ppm-group-tab")),
  users: [],
  groups: [],
  activeGroup: null,
  expenses: [],
  balances: null,
  feed: [],
  settlements: [],
  globalFeed: [],
  participantEditorOpen: false,
};

const authView = document.getElementById("auth-view");
const appView = document.getElementById("app-view");
const toastEl = document.getElementById("toast");

const loginForm = document.getElementById("login-form");
const registerForm = document.getElementById("register-form");
const groupForm = document.getElementById("group-form");
const expenseForm = document.getElementById("expense-form");
const manualSettlementForm = document.getElementById("manual-settlement-form");
const profileForm = document.getElementById("profile-form");

const currentUserAvatar = document.getElementById("current-user-avatar");
const currentUserAvatarFallback = document.getElementById("current-user-avatar-fallback");
const currentUserPhone = document.getElementById("current-user-phone");
const profileAvatarPreview = document.getElementById("profile-avatar-preview");
const profileAvatarFallback = document.getElementById("profile-avatar-fallback");
const profileDisplayName = document.getElementById("profile-display-name");
const profileDisplayEmail = document.getElementById("profile-display-email");
const profileDisplayPhone = document.getElementById("profile-display-phone");

const expenseGroupSelect = document.getElementById("expense-group-select");
const expensePayerSelect = document.getElementById("expense-payer");
const participantList = document.getElementById("participant-list");
const addExpenseFab = document.getElementById("add-expense-fab");
const groupCreatorSheet = document.getElementById("group-creator-sheet");

document.getElementById("show-login").addEventListener("click", () => toggleAuthMode("login"));
document.getElementById("show-register").addEventListener("click", () => toggleAuthMode("register"));
document.getElementById("reload-all-btn").addEventListener("click", bootstrapApp);
document.getElementById("open-group-creator-btn").addEventListener("click", openGroupCreator);
document.getElementById("close-group-creator-btn").addEventListener("click", closeGroupCreator);
document.getElementById("logout-btn").addEventListener("click", logout);
document.getElementById("toggle-participants-btn").addEventListener("click", toggleParticipantsEditor);
addExpenseFab.addEventListener("click", () => {
  setActiveView("expenses");
  focusExpenseAmount();
});

loginForm.addEventListener("submit", handleLogin);
registerForm.addEventListener("submit", handleRegister);
groupForm.addEventListener("submit", handleCreateGroup);
expenseForm.addEventListener("submit", handleCreateExpense);
manualSettlementForm.addEventListener("submit", handleCreateSettlement);
profileForm.addEventListener("submit", handleUpdateProfile);
profileForm.addEventListener("input", syncProfilePreviewFromForm);
expenseGroupSelect.addEventListener("change", handleExpenseGroupChange);

document.querySelectorAll(".tab-btn").forEach((button) => {
  button.addEventListener("click", () => setActiveView(button.dataset.view));
});

document.querySelectorAll(".subtab-btn").forEach((button) => {
  button.addEventListener("click", () => setGroupDetailTab(button.dataset.groupTab));
});

toggleAuthMode("login");
resetAuthTimers();
renderApp();
if (state.currentUser) {
  bootstrapApp();
}

function loadJson(key) {
  try {
    const value = localStorage.getItem(key);
    return value ? JSON.parse(value) : null;
  } catch {
    return null;
  }
}

function loadNumber(key) {
  const raw = localStorage.getItem(key);
  return raw ? Number(raw) : null;
}

function sanitizeView(value) {
  return APP_VIEWS.has(value) ? value : "groups";
}

function sanitizeGroupTab(value) {
  return GROUP_TABS.has(value) ? value : "expenses";
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
  localStorage.setItem("ppm-group-tab", state.groupDetailTab);
}

function resetAuthTimers() {
  const startedAt = Date.now() / 1000;
  loginForm.dataset.startedAt = String(startedAt);
  registerForm.dataset.startedAt = String(startedAt);
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
      const payload = await response.json();
      message = payload.detail || message;
    } catch {
      // ignore
    }
    throw new Error(message);
  }

  const contentType = response.headers.get("content-type") || "";
  return contentType.includes("application/json") ? response.json() : null;
}

function toggleAuthMode(mode) {
  const loginMode = mode === "login";
  loginForm.classList.toggle("hidden", !loginMode);
  registerForm.classList.toggle("hidden", loginMode);
  document.getElementById("show-login").classList.toggle("active", loginMode);
  document.getElementById("show-register").classList.toggle("active", !loginMode);
  resetAuthTimers();
}

function setActiveView(view) {
  state.activeView = sanitizeView(view);
  persistState();
  renderApp();
}

function setGroupDetailTab(tab) {
  state.groupDetailTab = sanitizeGroupTab(tab);
  persistState();
  renderGroupDetailTabs();
}

async function setActiveGroup(groupId, targetView = null) {
  state.activeGroupId = Number(groupId) || null;
  state.participantEditorOpen = false;
  persistState();
  await loadActiveGroupData();
  if (targetView) {
    state.activeView = sanitizeView(targetView);
  }
  persistState();
  renderApp();
}

function openGroupCreator() {
  groupCreatorSheet.classList.remove("hidden");
}

function closeGroupCreator() {
  groupCreatorSheet.classList.add("hidden");
}

function toggleParticipantsEditor() {
  state.participantEditorOpen = !state.participantEditorOpen;
  renderExpenseForm();
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
    loginForm.reset();
    showToast("Sesion iniciada.", "success");
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
    registerForm.reset();
    showToast("Cuenta creada.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

function logout() {
  state.currentUser = null;
  state.users = [];
  state.groups = [];
  state.activeGroup = null;
  state.expenses = [];
  state.balances = null;
  state.feed = [];
  state.settlements = [];
  state.globalFeed = [];
  state.activeGroupId = null;
  state.activeView = "groups";
  state.groupDetailTab = "expenses";
  state.participantEditorOpen = false;
  persistState();
  renderApp();
}

async function bootstrapApp() {
  if (!state.currentUser) {
    renderApp();
    return;
  }

  try {
    const [users, groups] = await Promise.all([api("/users"), api(`/users/${state.currentUser.id}/groups`)]);
    state.users = users;
    await hydrateGroupCards(groups);

    if (!state.groups.length) {
      state.activeGroupId = null;
      await loadActiveGroupData();
      persistState();
      renderApp();
      return;
    }

    if (!state.groups.some((group) => group.id === state.activeGroupId)) {
      state.activeGroupId = state.groups[0].id;
    }

    await loadActiveGroupData();
    persistState();
    renderApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function hydrateGroupCards(groups) {
  const enriched = await Promise.all(
    groups.map(async (group) => {
      try {
        const [balances, feed] = await Promise.all([
          api(`/groups/${group.id}/balances`).catch(() => null),
          api(`/groups/${group.id}/feed`).catch(() => []),
        ]);

        return {
          ...group,
          my_net_balance: getUserNetFromBalances(balances),
          last_activity: feed[0] || null,
          feed_preview: feed.slice(0, 6),
        };
      } catch {
        return { ...group, my_net_balance: 0, last_activity: null, feed_preview: [] };
      }
    })
  );

  state.groups = enriched;
  state.globalFeed = enriched
    .flatMap((group) =>
      (group.feed_preview || []).map((event) => ({
        ...event,
        group_name: group.name,
      }))
    )
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
}

async function loadActiveGroupData() {
  if (!state.activeGroupId) {
    state.activeGroup = null;
    state.expenses = [];
    state.balances = null;
    state.feed = [];
    state.settlements = [];
    return;
  }

  const [group, expenses, balances, feed, settlements] = await Promise.all([
    api(`/groups/${state.activeGroupId}`),
    api(`/groups/${state.activeGroupId}/expenses`),
    api(`/groups/${state.activeGroupId}/balances`),
    api(`/groups/${state.activeGroupId}/feed`),
    api(`/groups/${state.activeGroupId}/settlements`),
  ]);

  state.activeGroup = group;
  state.expenses = expenses;
  state.balances = balances;
  state.feed = feed;
  state.settlements = settlements;
}

async function handleCreateGroup(event) {
  event.preventDefault();
  const formData = new FormData(groupForm);
  const invitedIds = Array.from(document.getElementById("group-invite-list").selectedOptions).map((option) => Number(option.value));

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

    groupForm.reset();
    closeGroupCreator();
    showToast("Grupo creado.", "success");
    await bootstrapApp();
    await setActiveGroup(group.id, "groups");
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleCreateExpense(event) {
  event.preventDefault();
  const formData = new FormData(expenseForm);
  const groupId = Number(formData.get("groupId"));
  const participantIds = Array.from(participantList.querySelectorAll('input[name="participantIds"]:checked')).map((input) => Number(input.value));

  try {
    await api("/expenses", {
      method: "POST",
      body: JSON.stringify({
        group_id: groupId,
        payer_id: Number(formData.get("payerId")),
        description: formData.get("description"),
        amount: Number(formData.get("amount")),
        participant_ids: participantIds,
      }),
    });

    state.activeGroupId = groupId;
    state.participantEditorOpen = false;
    showToast("Gasto guardado.", "success");
    await bootstrapApp();
    expenseForm.reset();
    renderExpenseForm();
    focusExpenseAmount();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleCreateSettlement(event) {
  event.preventDefault();
  if (!state.activeGroupId) {
    return;
  }

  const formData = new FormData(manualSettlementForm);
  try {
    await api(`/groups/${state.activeGroupId}/settlements`, {
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
    showToast("Liquidacion guardada.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleQuickSettlement(settlement) {
  try {
    await api(`/groups/${state.activeGroupId}/settlements`, {
      method: "POST",
      body: JSON.stringify({
        actor_id: state.currentUser.id,
        from_user_id: settlement.from_user.id,
        to_user_id: settlement.to_user.id,
        amount: settlement.amount,
        notes: "Liquidacion marcada desde saldos",
      }),
    });
    showToast("Deuda saldada.", "success");
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
    showToast("Pago confirmado.", "success");
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

async function handleExpenseGroupChange() {
  const selectedId = Number(expenseGroupSelect.value);
  if (!selectedId || selectedId === state.activeGroupId) {
    return;
  }
  await setActiveGroup(selectedId);
  renderExpenseForm();
}

function renderApp() {
  const loggedIn = Boolean(state.currentUser);
  authView.classList.toggle("hidden", loggedIn);
  appView.classList.toggle("hidden", !loggedIn);

  if (!loggedIn) {
    return;
  }

  renderTopbar();
  renderTabs();
  renderViewVisibility();
  renderGroupCreatorOptions();
  renderGroupsView();
  renderExpenseForm();
  renderActivityView();
  renderAccountView();
  renderFab();
}

function renderTopbar() {
  document.getElementById("current-user-name").textContent = userLabel(state.currentUser);
  document.getElementById("current-user-email").textContent = state.currentUser.email;
  syncAvatar(currentUserAvatar, currentUserAvatarFallback, state.currentUser.avatar_url, initials(state.currentUser));
}

function renderTabs() {
  document.querySelectorAll(".tab-btn").forEach((button) => {
    button.classList.toggle("active", button.dataset.view === state.activeView);
  });
}

function renderViewVisibility() {
  document.querySelectorAll(".view-panel").forEach((panel) => panel.classList.add("hidden"));
  const active = document.getElementById(`view-${state.activeView}`);
  if (active) {
    active.classList.remove("hidden");
  }
}

function renderFab() {
  addExpenseFab.classList.toggle("hidden", !state.activeGroup);
}

function renderGroupsView() {
  renderGroupsList();
  renderGroupDetail();
}

function renderGroupsList() {
  const wrap = document.getElementById("group-list");
  wrap.innerHTML = "";

  if (!state.groups.length) {
    wrap.innerHTML = '<div class="info-card"><strong>Sin grupos todavia</strong><span class="muted small">Crea uno para empezar a registrar gastos.</span></div>';
    return;
  }

  state.groups.forEach((group) => {
    const button = document.createElement("button");
    button.className = `group-card ${group.id === state.activeGroupId ? "active" : ""}`;
    button.type = "button";
    button.innerHTML = `
      <strong>${escapeHtml(group.name)}</strong>
      <div class="inline-row">
        <span class="balance-chip ${balanceTone(group.my_net_balance)}">${escapeHtml(balanceText(group.my_net_balance))}</span>
      </div>
      <small class="muted">${escapeHtml(group.last_activity ? group.last_activity.message : "Sin actividad reciente")}</small>
    `;
    button.addEventListener("click", () => setActiveGroup(group.id, "groups"));
    wrap.appendChild(button);
  });
}

function renderGroupDetail() {
  const nameEl = document.getElementById("active-group-name");
  const descriptionEl = document.getElementById("active-group-description");
  const balanceEl = document.getElementById("active-group-balance");
  const membersEl = document.getElementById("active-group-members");
  const expenseFeedEl = document.getElementById("group-expense-feed");

  if (!state.activeGroup) {
    nameEl.textContent = "Sin grupo";
    descriptionEl.textContent = "Crea un grupo o toca uno de la lista para empezar.";
    balanceEl.textContent = "Sin saldo";
    membersEl.innerHTML = "";
    expenseFeedEl.innerHTML = '<div class="feed-item"><strong>Sin grupo activo</strong><span class="muted small">Cuando elijas un grupo, aqui veras sus gastos y saldos.</span></div>';
    document.getElementById("balances-list").innerHTML = "";
    document.getElementById("settlements-list").innerHTML = "";
    document.getElementById("settlement-history").innerHTML = "";
    renderGroupDetailTabs();
    return;
  }

  const activeCard = state.groups.find((group) => group.id === state.activeGroupId);
  nameEl.textContent = state.activeGroup.name;
  descriptionEl.textContent = state.activeGroup.description || "Sin descripcion.";
  balanceEl.textContent = balanceText(activeCard?.my_net_balance || 0);

  membersEl.innerHTML = "";
  state.activeGroup.members.forEach((member) => {
    const chip = document.createElement("div");
    chip.className = "member-chip";
    chip.innerHTML = `
      <strong>${escapeHtml(userLabel(member.user))}</strong>
      <span class="muted small">@${escapeHtml(member.user.username)}</span>
    `;
    membersEl.appendChild(chip);
  });

  expenseFeedEl.innerHTML = "";
  if (!state.expenses.length) {
    expenseFeedEl.innerHTML = '<div class="feed-item"><strong>Sin gastos todavia</strong><span class="muted small">Toca “Agregar gasto” y registra el primero.</span></div>';
  } else {
    state.expenses.forEach((expense) => {
      const item = document.createElement("div");
      item.className = "feed-item group-expense-row";
      item.innerHTML = `
        <strong>${escapeHtml(expense.description)}</strong>
        <span>${escapeHtml(expenseHeadline(expense))}</span>
        <span class="muted small">${escapeHtml(expenseDetail(expense))}</span>
      `;
      expenseFeedEl.appendChild(item);
    });
  }

  renderBalancesSection();
  renderGroupDetailTabs();
}

function renderGroupDetailTabs() {
  document.querySelectorAll(".subtab-btn").forEach((button) => {
    button.classList.toggle("active", button.dataset.groupTab === state.groupDetailTab);
  });
  document.getElementById("group-tab-expenses").classList.toggle("hidden", state.groupDetailTab !== "expenses");
  document.getElementById("group-tab-balances").classList.toggle("hidden", state.groupDetailTab !== "balances");
}

function renderBalancesSection() {
  const balancesEl = document.getElementById("balances-list");
  const settlementsEl = document.getElementById("settlements-list");
  const historyEl = document.getElementById("settlement-history");

  balancesEl.innerHTML = "";
  settlementsEl.innerHTML = "";
  historyEl.innerHTML = "";

  if (!state.balances) {
    balancesEl.innerHTML = '<div class="balance-row"><strong>Sin balances</strong><span class="muted small">Aparecen despues del primer gasto.</span></div>';
    settlementsEl.innerHTML = '<div class="settlement-row"><strong>Sin sugerencias</strong><span class="muted small">Todavia no hay saldos por cerrar.</span></div>';
    historyEl.innerHTML = '<div class="feed-item"><strong>Sin historial</strong><span class="muted small">Todavia no hay liquidaciones registradas.</span></div>';
    return;
  }

  state.balances.balances.forEach((entry) => {
    const row = document.createElement("div");
    row.className = "balance-row";
    row.innerHTML = `
      <strong>${escapeHtml(userLabel(entry.user))}</strong>
      <span class="balance-chip ${balanceTone(entry.net)}">${escapeHtml(balanceText(entry.net))}</span>
      <span class="muted small">Pago ${money(entry.paid)} · Debe ${money(entry.owed)}</span>
    `;
    balancesEl.appendChild(row);
  });

  if (!state.balances.settlements.length) {
    settlementsEl.innerHTML = '<div class="settlement-row"><strong>Todo va al corriente</strong><span class="muted small">No hay deudas sugeridas por saldar.</span></div>';
  } else {
    state.balances.settlements.forEach((settlement) => {
      const row = document.createElement("div");
      row.className = "settlement-row";
      row.innerHTML = `
        <strong>${escapeHtml(userLabel(settlement.from_user))} debe pagar a ${escapeHtml(userLabel(settlement.to_user))}</strong>
        <span>${money(settlement.amount)}</span>
      `;
      if (settlement.from_user.id === state.currentUser.id) {
        const button = document.createElement("button");
        button.className = "primary-btn mini-btn";
        button.type = "button";
        button.textContent = "Saldar deuda";
        button.addEventListener("click", () => handleQuickSettlement(settlement));
        row.appendChild(button);
      }
      settlementsEl.appendChild(row);
    });
  }

  if (!state.settlements.length) {
    historyEl.innerHTML = '<div class="feed-item"><strong>Sin historial</strong><span class="muted small">Todavia no hay liquidaciones registradas.</span></div>';
    return;
  }

  state.settlements.forEach((settlement) => {
    const item = document.createElement("div");
    item.className = "feed-item";
    item.innerHTML = `
      <strong>${escapeHtml(userLabel(settlement.from_user))} pago a ${escapeHtml(userLabel(settlement.to_user))}</strong>
      <span>${money(settlement.amount)} · ${escapeHtml(settlement.notes || "Sin notas")}</span>
      <span class="muted small">${settlement.received_confirmed ? "Pago recibido confirmado" : "Pendiente por confirmar"}</span>
    `;
    if (!settlement.received_confirmed && settlement.to_user.id === state.currentUser.id) {
      const button = document.createElement("button");
      button.className = "ghost-btn mini-btn";
      button.type = "button";
      button.textContent = "Confirmar recibido";
      button.addEventListener("click", () => handleConfirmSettlement(settlement.id));
      item.appendChild(button);
    }
    historyEl.appendChild(item);
  });

  renderSettlementFormOptions();
}

function renderSettlementFormOptions() {
  const fromSelect = document.getElementById("settlement-from-user");
  const toSelect = document.getElementById("settlement-to-user");
  fromSelect.innerHTML = "";
  toSelect.innerHTML = "";

  if (!state.activeGroup) {
    return;
  }

  state.activeGroup.members.forEach((member) => {
    const label = userLabel(member.user);
    const fromOption = document.createElement("option");
    fromOption.value = String(member.user.id);
    fromOption.textContent = label;
    if (member.user.id === state.currentUser.id) {
      fromOption.selected = true;
    }

    const toOption = document.createElement("option");
    toOption.value = String(member.user.id);
    toOption.textContent = label;
    if (member.user.id !== state.currentUser.id && !toSelect.childElementCount) {
      toOption.selected = true;
    }

    fromSelect.appendChild(fromOption);
    toSelect.appendChild(toOption);
  });
}

function renderExpenseForm() {
  expenseGroupSelect.innerHTML = "";
  expensePayerSelect.innerHTML = "";
  participantList.innerHTML = "";

  if (!state.groups.length) {
    expenseGroupSelect.innerHTML = '<option value="">Primero crea un grupo</option>';
    expensePayerSelect.innerHTML = '<option value="">Sin usuarios</option>';
    participantList.innerHTML = '<div class="info-card"><span class="muted small">Necesitas un grupo para repartir el gasto.</span></div>';
    document.getElementById("expense-quick-feed").innerHTML = '<div class="feed-item"><strong>Sin gastos</strong><span class="muted small">Crea un grupo y registra el primero.</span></div>';
    return;
  }

  state.groups.forEach((group) => {
    const option = document.createElement("option");
    option.value = String(group.id);
    option.textContent = group.name;
    option.selected = group.id === state.activeGroupId;
    expenseGroupSelect.appendChild(option);
  });

  const members = state.activeGroup?.members || [];
  members.forEach((member) => {
    const option = document.createElement("option");
    option.value = String(member.user.id);
    option.textContent = userLabel(member.user);
    option.selected = member.user.id === state.currentUser.id;
    expensePayerSelect.appendChild(option);

    const label = document.createElement("label");
    label.innerHTML = `
      <input type="checkbox" name="participantIds" value="${member.user.id}" checked />
      <span>${escapeHtml(userLabel(member.user))}</span>
    `;
    participantList.appendChild(label);
  });

  participantList.classList.toggle("hidden", !state.participantEditorOpen);
  document.getElementById("toggle-participants-btn").textContent = state.participantEditorOpen ? "Ocultar" : "Cambiar";

  renderExpenseQuickFeed();
}

function renderExpenseQuickFeed() {
  const wrap = document.getElementById("expense-quick-feed");
  wrap.innerHTML = "";

  if (!state.expenses.length) {
    wrap.innerHTML = '<div class="feed-item"><strong>Sin gastos recientes</strong><span class="muted small">Cuando guardes uno, lo veras aqui enseguida.</span></div>';
    return;
  }

  state.expenses.slice(0, 6).forEach((expense) => {
    const item = document.createElement("div");
    item.className = "feed-item";
    item.innerHTML = `
      <strong>${escapeHtml(expense.description)}</strong>
      <span>${escapeHtml(expenseHeadline(expense))}</span>
      <span class="muted small">${formatDate(expense.created_at)}</span>
    `;
    wrap.appendChild(item);
  });
}

function renderActivityView() {
  const wrap = document.getElementById("global-feed-list");
  wrap.innerHTML = "";

  if (!state.globalFeed.length) {
    wrap.innerHTML = '<div class="feed-item"><strong>Sin actividad global</strong><span class="muted small">Todo lo que pase en tus grupos aparecera aqui.</span></div>';
    return;
  }

  state.globalFeed.forEach((event) => {
    const item = document.createElement("div");
    item.className = "feed-item";
    item.innerHTML = `
      <strong>${escapeHtml(event.group_name)}</strong>
      <span>${escapeHtml(event.message)}</span>
      <span class="muted small">${formatDate(event.created_at)}</span>
    `;
    wrap.appendChild(item);
  });
}

function renderAccountView() {
  profileForm.elements.username.value = state.currentUser.username || "";
  profileForm.elements.firstName.value = state.currentUser.first_name || "";
  profileForm.elements.lastName.value = state.currentUser.last_name || "";
  profileForm.elements.phoneNumber.value = state.currentUser.phone_number || "";
  profileForm.elements.avatarUrl.value = state.currentUser.avatar_url || "";

  currentUserPhone.textContent = state.currentUser.phone_number || "Sin telefono guardado";
  profileDisplayName.textContent = userLabel(state.currentUser);
  profileDisplayEmail.textContent = state.currentUser.email;
  profileDisplayPhone.textContent = state.currentUser.phone_number || "Agrega tu telefono para identificarte mejor.";
  syncAvatar(profileAvatarPreview, profileAvatarFallback, state.currentUser.avatar_url, initials(state.currentUser));
  syncProfilePreviewFromForm();
}

function renderGroupCreatorOptions() {
  const inviteSelect = document.getElementById("group-invite-list");
  inviteSelect.innerHTML = "";

  state.users
    .filter((user) => user.id !== state.currentUser.id)
    .forEach((user) => {
      const option = document.createElement("option");
      option.value = String(user.id);
      option.textContent = `${userLabel(user)} (${user.email})`;
      inviteSelect.appendChild(option);
    });
}

function getUserNetFromBalances(balances) {
  if (!balances?.balances) {
    return 0;
  }
  const entry = balances.balances.find((item) => item.user.id === state.currentUser.id);
  return entry ? Number(entry.net || 0) : 0;
}

function balanceTone(value) {
  if (value > 0) {
    return "positive";
  }
  if (value < 0) {
    return "negative";
  }
  return "neutral";
}

function balanceText(value) {
  const amount = Math.abs(Number(value || 0));
  if (value > 0) {
    return `Te deben ${money(amount)}`;
  }
  if (value < 0) {
    return `Debes ${money(amount)}`;
  }
  return "Vas parejo";
}

function expenseHeadline(expense) {
  const meId = state.currentUser.id;
  const payerId = expense.payer.id;
  const myShare = expense.participants.find((participant) => participant.id === meId || participant.user_id === meId);

  if (payerId === meId) {
    const othersOwe = expense.participants.reduce((total, participant) => {
      const participantId = participant.id || participant.user_id;
      if (participantId === meId) {
        return total;
      }
      return total + Number(participant.share_amount || 0);
    }, 0);
    return othersOwe > 0 ? `Pagaste ${money(expense.amount)} · Te deben ${money(othersOwe)}` : `Pagaste ${money(expense.amount)}`;
  }

  if (myShare) {
    return `${expense.payer.username} pago ${money(expense.amount)} · Tu debes ${money(myShare.share_amount)}`;
  }

  return `${expense.payer.username} pago ${money(expense.amount)}`;
}

function expenseDetail(expense) {
  const people = expense.participants.map((participant) => participant.username).join(", ");
  return `Se dividio entre ${people}`;
}

function userLabel(user) {
  return user.display_name || user.full_name || user.username;
}

function initials(user) {
  const value = userLabel(user).trim();
  const parts = value.split(/\s+/).filter(Boolean);
  return (parts.slice(0, 2).map((part) => part[0].toUpperCase()).join("") || "P").slice(0, 2);
}

function syncAvatar(imageEl, fallbackEl, url, fallbackText) {
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
  const previewUser = {
    username: String(profileForm.elements.username.value || "").trim() || state.currentUser.username,
    display_name:
      [String(profileForm.elements.firstName.value || "").trim(), String(profileForm.elements.lastName.value || "").trim()]
        .filter(Boolean)
        .join(" ") || String(profileForm.elements.username.value || "").trim() || state.currentUser.username,
    avatar_url: String(profileForm.elements.avatarUrl.value || "").trim(),
  };
  const phone = String(profileForm.elements.phoneNumber.value || "").trim();

  profileDisplayName.textContent = userLabel(previewUser);
  profileDisplayEmail.textContent = state.currentUser.email;
  profileDisplayPhone.textContent = phone || "Agrega tu telefono para identificarte mejor.";
  syncAvatar(profileAvatarPreview, profileAvatarFallback, previewUser.avatar_url, initials(previewUser));
}

function focusExpenseAmount() {
  const amountInput = expenseForm.elements.amount;
  if (amountInput) {
    setTimeout(() => amountInput.focus(), 80);
  }
}

function money(amount) {
  return new Intl.NumberFormat("es-MX", {
    style: "currency",
    currency: "MXN",
  }).format(Number(amount || 0));
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

function showToast(message, type) {
  toastEl.textContent = message;
  toastEl.className = `toast ${type}`;
  setTimeout(() => {
    toastEl.className = "toast hidden";
  }, 3000);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
