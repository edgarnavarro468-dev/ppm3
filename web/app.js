const API_BASE = "";

const state = {
  currentUser: loadCurrentUser(),
  groups: [],
  users: [],
  summary: null,
  activeGroupId: loadActiveGroupId(),
  activeGroup: null,
  expenses: [],
  balances: null,
  feed: [],
};

const authView = document.getElementById("auth-view");
const appView = document.getElementById("app-view");
const toastEl = document.getElementById("toast");

const loginForm = document.getElementById("login-form");
const registerForm = document.getElementById("register-form");
const showLoginBtn = document.getElementById("show-login");
const showRegisterBtn = document.getElementById("show-register");
const logoutBtn = document.getElementById("logout-btn");
const refreshGroupsBtn = document.getElementById("refresh-groups-btn");
const reloadAllBtn = document.getElementById("reload-all-btn");
const groupForm = document.getElementById("group-form");
const expenseForm = document.getElementById("expense-form");
const addMemberBtn = document.getElementById("add-member-btn");

showLoginBtn.addEventListener("click", () => toggleAuthMode("login"));
showRegisterBtn.addEventListener("click", () => toggleAuthMode("register"));
loginForm.addEventListener("submit", handleLogin);
registerForm.addEventListener("submit", handleRegister);
logoutBtn.addEventListener("click", logout);
refreshGroupsBtn.addEventListener("click", bootstrapApp);
reloadAllBtn.addEventListener("click", bootstrapApp);
groupForm.addEventListener("submit", handleCreateGroup);
expenseForm.addEventListener("submit", handleCreateExpense);
addMemberBtn.addEventListener("click", handleAddMember);

toggleAuthMode("login");
renderApp();
if (state.currentUser) {
  bootstrapApp();
}

function loadCurrentUser() {
  try {
    const raw = localStorage.getItem("ppm-current-user");
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function loadActiveGroupId() {
  const value = localStorage.getItem("ppm-active-group-id");
  return value ? Number(value) : null;
}

function saveSession() {
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
    saveSession();
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
    saveSession();
    showToast("Cuenta creada. Ya puedes probar la app.", "success");
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
  saveSession();
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
      saveSession();
      renderApp();
      return;
    }

    const hasActiveGroup = state.groups.some((group) => group.id === state.activeGroupId);
    if (!hasActiveGroup) {
      state.activeGroupId = state.groups[0].id;
    }

    saveSession();
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
    return;
  }

  const [group, expenses, balances, feed] = await Promise.all([
    api(`/groups/${state.activeGroupId}`),
    api(`/groups/${state.activeGroupId}/expenses`),
    api(`/groups/${state.activeGroupId}/balances`),
    api(`/groups/${state.activeGroupId}/feed`),
  ]);

  state.activeGroup = group;
  state.expenses = expenses;
  state.balances = balances;
  state.feed = feed;
}

async function handleCreateGroup(event) {
  event.preventDefault();
  if (!state.currentUser) {
    return;
  }

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
    groupForm.reset();
    state.activeGroupId = group.id;
    saveSession();
    showToast("Grupo creado.", "success");
    await bootstrapApp();
  } catch (error) {
    showToast(error.message, "error");
  }
}

async function handleAddMember() {
  const select = document.getElementById("member-add-select");
  const userId = Number(select.value);
  if (!userId || !state.activeGroupId) {
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
    showToast("Primero elige un grupo.", "error");
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

function toggleAuthMode(mode) {
  const loginActive = mode === "login";
  loginForm.classList.toggle("hidden", !loginActive);
  registerForm.classList.toggle("hidden", loginActive);
  showLoginBtn.classList.toggle("active", loginActive);
  showRegisterBtn.classList.toggle("active", !loginActive);
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

  renderMetrics();
  renderGroups();
  renderActiveGroup();
  renderExpenseForm();
  renderBalances();
  renderFeed();
  renderRecentExpenses();
  renderInviteOptions();
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
  document.getElementById("metric-group-count").textContent = String(summary.group_count);
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
      saveSession();
      await loadActiveGroupData();
      renderApp();
    });
    wrap.appendChild(item);
  });
}

function renderActiveGroup() {
  const nameEl = document.getElementById("active-group-name");
  const descEl = document.getElementById("active-group-description");
  const membersEl = document.getElementById("active-group-members");
  const addMemberWrap = document.getElementById("member-add-wrap");
  const addMemberSelect = document.getElementById("member-add-select");

  membersEl.innerHTML = "";
  addMemberSelect.innerHTML = "";

  if (!state.activeGroup) {
    nameEl.textContent = "Sin grupo";
    descEl.textContent = "Crea un grupo para empezar a probar.";
    addMemberWrap.classList.add("hidden");
    return;
  }

  nameEl.textContent = state.activeGroup.name;
  descEl.textContent = state.activeGroup.description || "Este grupo aun no tiene descripcion.";

  state.activeGroup.members.forEach((member) => {
    const chip = document.createElement("div");
    chip.className = "member-chip";
    chip.innerHTML = `<strong>${escapeHtml(member.username)}</strong><span class="muted small">${escapeHtml(
      member.email
    )}</span>`;
    membersEl.appendChild(chip);
  });

  const presentIds = new Set(state.activeGroup.members.map((member) => member.id));
  const availableUsers = state.users.filter((user) => !presentIds.has(user.id));

  if (!availableUsers.length) {
    addMemberWrap.classList.add("hidden");
    return;
  }

  addMemberWrap.classList.remove("hidden");
  availableUsers.forEach((user) => {
    const option = document.createElement("option");
    option.value = String(user.id);
    option.textContent = `${user.username} (${user.email})`;
    addMemberSelect.appendChild(option);
  });
}

function renderExpenseForm() {
  const payerSelect = document.getElementById("expense-payer");
  const participantList = document.getElementById("participant-list");
  payerSelect.innerHTML = "";
  participantList.innerHTML = "";

  if (!state.activeGroup) {
    payerSelect.innerHTML = '<option value="">Primero crea un grupo</option>';
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
  });
}

function renderBalances() {
  const balancesEl = document.getElementById("balances-list");
  const settlementsEl = document.getElementById("settlements-list");
  balancesEl.innerHTML = "";
  settlementsEl.innerHTML = "";

  if (!state.balances) {
    balancesEl.innerHTML = '<div class="balance-item muted small">No hay balances todavia.</div>';
    settlementsEl.innerHTML = '<div class="settlement-item muted small">Sin datos.</div>';
    return;
  }

  state.balances.balances.forEach((entry) => {
    const div = document.createElement("div");
    div.className = "balance-item";
    div.innerHTML = `
      <strong>${escapeHtml(entry.user.username)}</strong>
      <span class="muted small">Pago ${money(entry.paid)} | Debe ${money(entry.owed)} | Neto ${money(entry.net)}</span>
    `;
    balancesEl.appendChild(div);
  });

  if (!state.balances.settlements.length) {
    settlementsEl.innerHTML = '<div class="settlement-item muted small">Todo esta balanceado.</div>';
    return;
  }

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

function renderFeed() {
  const feedEl = document.getElementById("feed-list");
  feedEl.innerHTML = "";

  if (!state.feed.length) {
    feedEl.innerHTML = '<div class="feed-item muted small">Todavia no hay actividad.</div>';
    return;
  }

  state.feed.forEach((event) => {
    const item = document.createElement("div");
    item.className = "feed-item";
    item.innerHTML = `
      <strong>${formatDate(event.created_at)}</strong>
      <div>${escapeHtml(event.message)}</div>
    `;
    feedEl.appendChild(item);
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
  const users = state.users.filter((user) => !state.currentUser || user.id !== state.currentUser.id);

  users.forEach((user) => {
    const option = document.createElement("option");
    option.value = String(user.id);
    option.textContent = `${user.username} (${user.email})`;
    inviteSelect.appendChild(option);
  });
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
  }, 2800);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
