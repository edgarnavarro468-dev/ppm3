from datetime import datetime

import requests
import streamlit as st
from plotly import graph_objects as go


API_URL = "http://localhost:8000"

st.set_page_config(
    page_title="PPM - Finanzas Sociales",
    layout="wide",
    initial_sidebar_state="expanded",
)


st.markdown(
    """
    <style>
        .ppm-hero {
            padding: 1.8rem;
            border-radius: 12px;
            background: linear-gradient(135deg, #0f172a 0%, #155e75 55%, #0f766e 100%);
            color: white;
            margin-bottom: 1.5rem;
        }
        .ppm-card {
            background: #ffffff;
            border: 1px solid #dbe4ec;
            border-radius: 10px;
            padding: 1rem;
        }
        .ppm-feed-item {
            border-left: 4px solid #155e75;
            background: #f8fafc;
            border-radius: 8px;
            padding: 0.9rem;
            margin-bottom: 0.75rem;
        }
    </style>
    """,
    unsafe_allow_html=True,
)


for key, value in {
    "authenticated": False,
    "current_user": None,
    "auth_page": "login",
    "active_group_id": None,
}.items():
    if key not in st.session_state:
        st.session_state[key] = value


def format_money(amount: float) -> str:
    return f"${amount:,.2f}"


def api_request(method: str, endpoint: str, payload: dict | None = None, params: dict | None = None):
    try:
        response = requests.request(
            method=method,
            url=f"{API_URL}{endpoint}",
            json=payload,
            params=params,
            timeout=8,
        )
    except requests.RequestException as exc:
        st.error(f"No se pudo conectar con la API: {exc}")
        return None

    if response.ok:
        if response.content:
            return response.json()
        return None

    detail = "Ocurrio un error con la API."
    try:
        body = response.json()
        detail = body.get("detail", detail)
    except ValueError:
        pass
    st.error(detail)
    return None


def load_groups() -> list[dict]:
    if not st.session_state.current_user:
        return []
    groups = api_request("GET", f"/users/{st.session_state.current_user['id']}/groups")
    return groups or []


def ensure_active_group(groups: list[dict]) -> None:
    if not groups:
        st.session_state.active_group_id = None
        return
    group_ids = {group["id"] for group in groups}
    if st.session_state.active_group_id not in group_ids:
        st.session_state.active_group_id = groups[0]["id"]


def render_login() -> None:
    col1, col2, col3 = st.columns([1, 1.2, 1])
    with col2:
        st.markdown(
            """
            <div class="ppm-hero">
                <h1 style="margin:0;">PPM</h1>
                <p style="margin:0.5rem 0 0 0;">Finanzas sociales para grupos de amigos</p>
            </div>
            """,
            unsafe_allow_html=True,
        )

        with st.form("login_form"):
            email = st.text_input("Correo electronico")
            password = st.text_input("Contrasena", type="password")
            submitted = st.form_submit_button("Iniciar sesion", use_container_width=True)

        if submitted:
            result = api_request(
                "POST",
                "/auth/login",
                payload={"email": email.strip().lower(), "password": password},
            )
            if result:
                st.session_state.authenticated = True
                st.session_state.current_user = result["user"]
                st.rerun()

        st.caption("Todavia no tienes cuenta?")
        if st.button("Crear cuenta", use_container_width=True):
            st.session_state.auth_page = "register"
            st.rerun()


def render_register() -> None:
    col1, col2, col3 = st.columns([1, 1.2, 1])
    with col2:
        st.markdown(
            """
            <div class="ppm-hero">
                <h1 style="margin:0;">Crear cuenta</h1>
                <p style="margin:0.5rem 0 0 0;">Empieza a organizar gastos sin dramas</p>
            </div>
            """,
            unsafe_allow_html=True,
        )

        with st.form("register_form"):
            username = st.text_input("Nombre")
            email = st.text_input("Correo electronico")
            password = st.text_input("Contrasena", type="password")
            confirm_password = st.text_input("Confirmar contrasena", type="password")
            submitted = st.form_submit_button("Registrarme", use_container_width=True)

        if submitted:
            if password != confirm_password:
                st.warning("Las contrasenas no coinciden.")
            else:
                result = api_request(
                    "POST",
                    "/auth/register",
                    payload={
                        "username": username.strip(),
                        "email": email.strip().lower(),
                        "password": password,
                    },
                )
                if result:
                    st.success("Cuenta creada. Ahora inicia sesion.")
                    st.session_state.auth_page = "login"
                    st.rerun()

        if st.button("Volver al login", use_container_width=True):
            st.session_state.auth_page = "login"
            st.rerun()


if not st.session_state.authenticated:
    if st.session_state.auth_page == "register":
        render_register()
    else:
        render_login()
    st.stop()


groups = load_groups()
ensure_active_group(groups)

with st.sidebar:
    st.markdown(f"## {st.session_state.current_user['username']}")
    st.caption(st.session_state.current_user["email"])

    if st.button("Cerrar sesion", use_container_width=True):
        st.session_state.authenticated = False
        st.session_state.current_user = None
        st.session_state.active_group_id = None
        st.session_state.auth_page = "login"
        st.rerun()

    st.markdown("---")
    page = st.radio(
        "Seccion",
        [
            "Dashboard",
            "Grupos",
            "Gastos",
            "Balances",
            "Feed Social",
            "Estadisticas",
        ],
    )

    if groups:
        group_labels = {group["name"]: group["id"] for group in groups}
        active_group_name = next(
            (group["name"] for group in groups if group["id"] == st.session_state.active_group_id),
            groups[0]["name"],
        )
        selected_group_name = st.selectbox(
            "Grupo activo",
            options=list(group_labels.keys()),
            index=list(group_labels.keys()).index(active_group_name),
        )
        st.session_state.active_group_id = group_labels[selected_group_name]
    else:
        st.info("Todavia no tienes grupos.")

    if st.button("Actualizar datos", use_container_width=True):
        st.rerun()


st.markdown(
    """
    <div class="ppm-hero">
        <h1 style="margin:0;">PPM - Finanzas Sociales</h1>
        <p style="margin:0.5rem 0 0 0;">Maneja dinero entre amigos con un historial compartido y claro.</p>
    </div>
    """,
    unsafe_allow_html=True,
)


active_group = None
if st.session_state.active_group_id:
    active_group = api_request("GET", f"/groups/{st.session_state.active_group_id}")


if page == "Dashboard":
    summary = api_request("GET", f"/users/{st.session_state.current_user['id']}/summary")
    if summary:
        col1, col2, col3, col4 = st.columns(4)
        metrics = [
            ("Gasto total del sistema", format_money(summary["total_expenses"])),
            ("Lo que has pagado", format_money(summary["total_paid"])),
            ("Balance neto", format_money(summary["net_balance"])),
            ("Tus grupos", str(summary["group_count"])),
        ]
        for column, (label, value) in zip([col1, col2, col3, col4], metrics):
            with column:
                st.metric(label, value)

        st.markdown("### Actividad reciente")
        recent_expenses = summary.get("recent_expenses", [])
        if recent_expenses:
            formatted_rows = []
            for expense in recent_expenses:
                formatted_rows.append(
                    {
                        "Grupo": expense["group_name"],
                        "Concepto": expense["description"],
                        "Monto": format_money(expense["amount"]),
                        "Pago": expense["payer_name"],
                        "Fecha": datetime.fromisoformat(expense["created_at"]).strftime("%Y-%m-%d %H:%M"),
                    }
                )
            st.table(formatted_rows)
        else:
            st.info("Todavia no hay gastos registrados.")


elif page == "Grupos":
    col1, col2 = st.columns([1, 1.5])

    with col1:
        st.markdown("### Crear grupo")
        users = api_request("GET", "/users") or []
        user_options = {user["username"]: user["id"] for user in users if user["id"] != st.session_state.current_user["id"]}
        with st.form("create_group_form"):
            name = st.text_input("Nombre del grupo", placeholder="Roomies, Viaje, PPM")
            description = st.text_area("Descripcion", placeholder="Para que usaran este grupo?")
            invited_names = st.multiselect("Invitar miembros", options=list(user_options.keys()))
            submitted = st.form_submit_button("Crear grupo", use_container_width=True)

        if submitted:
            invited_ids = [user_options[name_item] for name_item in invited_names]
            result = api_request(
                "POST",
                "/groups",
                payload={
                    "name": name,
                    "description": description,
                    "creator_id": st.session_state.current_user["id"],
                    "member_ids": invited_ids,
                },
            )
            if result:
                st.success("Grupo creado correctamente.")
                st.session_state.active_group_id = result["id"]
                st.rerun()

    with col2:
        st.markdown("### Tus grupos")
        if groups:
            for group in groups:
                with st.container(border=True):
                    st.subheader(group["name"])
                    st.caption(group["description"] or "Sin descripcion")
                    member_names = ", ".join(member["username"] for member in group["members"])
                    st.write(f"Miembros: {member_names}")
                    if st.button("Usar este grupo", key=f"use_group_{group['id']}"):
                        st.session_state.active_group_id = group["id"]
                        st.rerun()
        else:
            st.info("Crea tu primer grupo para empezar.")

        if active_group:
            st.markdown("### Miembros del grupo activo")
            member_rows = [
                {"Nombre": member["username"], "Correo": member["email"]}
                for member in active_group["members"]
            ]
            st.table(member_rows)


elif page == "Gastos":
    if not active_group:
        st.info("Necesitas un grupo activo para registrar gastos.")
    else:
        members = active_group["members"]
        member_labels = {member["username"]: member["id"] for member in members}

        col1, col2 = st.columns([1, 1.5])
        with col1:
            st.markdown(f"### Nuevo gasto en {active_group['name']}")
            with st.form("expense_form"):
                payer_name = st.selectbox("Quien pago?", options=list(member_labels.keys()))
                description = st.text_input("Concepto", placeholder="Cena, supermercado, renta")
                amount = st.number_input("Monto", min_value=0.01, step=10.0, format="%0.2f")
                participant_names = st.multiselect(
                    "Quienes comparten este gasto?",
                    options=list(member_labels.keys()),
                    default=list(member_labels.keys()),
                )
                submitted = st.form_submit_button("Guardar gasto", use_container_width=True)

            if submitted:
                result = api_request(
                    "POST",
                    "/expenses",
                    payload={
                        "group_id": active_group["id"],
                        "payer_id": member_labels[payer_name],
                        "description": description,
                        "amount": float(amount),
                        "participant_ids": [member_labels[name] for name in participant_names],
                    },
                )
                if result:
                    st.success("Gasto guardado.")
                    st.rerun()

        with col2:
            st.markdown("### Historial del grupo")
            expenses = api_request("GET", f"/groups/{active_group['id']}/expenses") or []
            if expenses:
                for expense in expenses:
                    participant_text = ", ".join(
                        f"{participant['username']} ({format_money(participant['share_amount'])})"
                        for participant in expense["participants"]
                    )
                    with st.container(border=True):
                        st.write(f"**{expense['description']}**")
                        st.write(
                            f"Pago {expense['payer']['username']} por {format_money(expense['amount'])}"
                        )
                        st.caption(f"Se divide entre: {participant_text}")
            else:
                st.info("Todavia no hay gastos en este grupo.")


elif page == "Balances":
    if not active_group:
        st.info("Selecciona o crea un grupo para ver balances.")
    else:
        balance_data = api_request("GET", f"/groups/{active_group['id']}/balances")
        if balance_data:
            st.markdown(f"### Balance de {active_group['name']}")
            balance_rows = []
            for balance in balance_data["balances"]:
                balance_rows.append(
                    {
                        "Nombre": balance["user"]["username"],
                        "Pagado": format_money(balance["paid"]),
                        "Debe": format_money(balance["owed"]),
                        "Neto": format_money(balance["net"]),
                    }
                )
            st.table(balance_rows)

            st.markdown("### Liquidaciones sugeridas")
            if balance_data["settlements"]:
                for settlement in balance_data["settlements"]:
                    st.write(
                        f"{settlement['from_user']['username']} debe pagar "
                        f"{format_money(settlement['amount'])} a {settlement['to_user']['username']}."
                    )
            else:
                st.success("Todo esta balanceado en este grupo.")


elif page == "Feed Social":
    if not active_group:
        st.info("Selecciona un grupo para ver su actividad.")
    else:
        events = api_request("GET", f"/groups/{active_group['id']}/feed") or []
        st.markdown(f"### Actividad de {active_group['name']}")
        if events:
            for event in events:
                timestamp = datetime.fromisoformat(event["created_at"]).strftime("%Y-%m-%d %H:%M")
                st.markdown(
                    f"""
                    <div class="ppm-feed-item">
                        <strong>{timestamp}</strong><br>
                        {event['message']}
                    </div>
                    """,
                    unsafe_allow_html=True,
                )
        else:
            st.info("Todavia no hay actividad en este grupo.")


elif page == "Estadisticas":
    if not active_group:
        st.info("Selecciona un grupo para ver sus estadisticas.")
    else:
        expenses = api_request("GET", f"/groups/{active_group['id']}/expenses") or []
        if not expenses:
            st.info("Todavia no hay datos para graficar.")
        else:
            rows = []
            for expense in expenses:
                rows.append(
                    {
                        "Concepto": expense["description"],
                        "Monto": expense["amount"],
                        "Pago": expense["payer"]["username"],
                        "Fecha": datetime.fromisoformat(expense["created_at"]),
                    }
                )
            rows.sort(key=lambda item: item["Fecha"])

            col1, col2 = st.columns(2)
            with col1:
                totals_by_user = {}
                for row in rows:
                    totals_by_user[row["Pago"]] = totals_by_user.get(row["Pago"], 0) + row["Monto"]
                fig = go.Figure(
                    data=[
                        go.Pie(
                            labels=list(totals_by_user.keys()),
                            values=list(totals_by_user.values()),
                        )
                    ]
                )
                fig.update_layout(title="Gastos por persona")
                st.plotly_chart(fig, use_container_width=True)

            with col2:
                top_rows = sorted(rows, key=lambda item: item["Monto"], reverse=True)[:5]
                fig = go.Figure(
                    data=[
                        go.Bar(
                            x=[row["Concepto"] for row in top_rows],
                            y=[row["Monto"] for row in top_rows],
                            text=[row["Pago"] for row in top_rows],
                            textposition="outside",
                        )
                    ]
                )
                fig.update_layout(title="Top gastos", xaxis_title="Concepto", yaxis_title="Monto")
                st.plotly_chart(fig, use_container_width=True)

            fig = go.Figure(
                data=[
                    go.Scatter(
                        x=list(range(1, len(rows) + 1)),
                        y=[row["Monto"] for row in rows],
                        mode="lines+markers",
                    )
                ]
            )
            fig.update_layout(title="Evolucion de gastos", xaxis_title="Orden", yaxis_title="Monto")
            st.plotly_chart(fig, use_container_width=True)


st.markdown("---")
st.caption(f"PPM Finanzas Sociales | {datetime.now().strftime('%Y')}")
