from collections import defaultdict
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from sqlalchemy.orm import joinedload

from backend.database import Expense, ExpenseParticipant, FeedEvent, Group, GroupMember, SessionLocal, User
from backend.security import hash_password, verify_password


app = FastAPI(title="PPM Finanzas Sociales API")
WEB_DIR = Path(__file__).resolve().parent.parent / "web"

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class RegisterInput(BaseModel):
    username: str = Field(min_length=2, max_length=120)
    email: str
    password: str = Field(min_length=6, max_length=120)


class LoginInput(BaseModel):
    email: str
    password: str


class GroupCreateInput(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    description: str = ""
    creator_id: int
    member_ids: list[int] = []


class MemberAddInput(BaseModel):
    user_id: int


class ExpenseCreateInput(BaseModel):
    group_id: int
    payer_id: int
    description: str = Field(min_length=2, max_length=255)
    amount: float = Field(gt=0)
    participant_ids: list[int]


def amount_to_cents(amount: float) -> int:
    decimal_amount = Decimal(str(amount)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return int(decimal_amount * 100)


def cents_to_amount(value: int) -> float:
    return float((Decimal(value) / Decimal("100")).quantize(Decimal("0.01")))


def serialize_user(user: User) -> dict:
    return {
        "id": user.id,
        "username": user.username,
        "email": user.email,
    }


def serialize_group(group: Group) -> dict:
    members = sorted(group.members, key=lambda membership: membership.user.username.lower())
    return {
        "id": group.id,
        "name": group.name,
        "description": group.description,
        "created_by": group.created_by,
        "created_at": group.created_at.isoformat(),
        "members": [serialize_user(member.user) for member in members],
    }


def serialize_expense(expense: Expense) -> dict:
    return {
        "id": expense.id,
        "group_id": expense.group_id,
        "description": expense.description,
        "amount": cents_to_amount(expense.amount_cents),
        "payer": serialize_user(expense.payer),
        "participants": [
            {
                "id": participant.user.id,
                "username": participant.user.username,
                "share_amount": cents_to_amount(participant.share_cents),
            }
            for participant in sorted(expense.participants, key=lambda item: item.user.username.lower())
        ],
        "created_at": expense.created_at.isoformat(),
    }


def add_feed_event(session, group_id: int, actor_id: int | None, event_type: str, message: str) -> None:
    session.add(
        FeedEvent(
            group_id=group_id,
            actor_id=actor_id,
            event_type=event_type,
            message=message,
        )
    )


def validate_group_member_ids(group: Group, user_ids: list[int]) -> None:
    group_member_ids = {member.user_id for member in group.members}
    invalid_ids = [user_id for user_id in user_ids if user_id not in group_member_ids]
    if invalid_ids:
        raise HTTPException(status_code=400, detail="Hay usuarios que no pertenecen al grupo.")


def build_group_balance_payload(group: Group) -> dict:
    paid_totals = defaultdict(int)
    owed_totals = defaultdict(int)
    net_totals = defaultdict(int)

    for member in group.members:
        paid_totals[member.user_id] = 0
        owed_totals[member.user_id] = 0
        net_totals[member.user_id] = 0

    for expense in group.expenses:
        paid_totals[expense.payer_id] += expense.amount_cents
        net_totals[expense.payer_id] += expense.amount_cents
        for participant in expense.participants:
            owed_totals[participant.user_id] += participant.share_cents
            net_totals[participant.user_id] -= participant.share_cents

    balances = []
    for member in sorted(group.members, key=lambda item: item.user.username.lower()):
        user_id = member.user_id
        balances.append(
            {
                "user": serialize_user(member.user),
                "paid": cents_to_amount(paid_totals[user_id]),
                "owed": cents_to_amount(owed_totals[user_id]),
                "net": cents_to_amount(net_totals[user_id]),
            }
        )

    creditors = []
    debtors = []
    for balance in balances:
        cents_value = amount_to_cents(balance["net"])
        if cents_value > 0:
            creditors.append({"user": balance["user"], "remaining_cents": cents_value})
        elif cents_value < 0:
            debtors.append({"user": balance["user"], "remaining_cents": abs(cents_value)})

    settlements = []
    creditor_index = 0
    debtor_index = 0

    while creditor_index < len(creditors) and debtor_index < len(debtors):
        creditor = creditors[creditor_index]
        debtor = debtors[debtor_index]
        payment_cents = min(creditor["remaining_cents"], debtor["remaining_cents"])
        settlements.append(
            {
                "from_user": debtor["user"],
                "to_user": creditor["user"],
                "amount": cents_to_amount(payment_cents),
            }
        )
        creditor["remaining_cents"] -= payment_cents
        debtor["remaining_cents"] -= payment_cents
        if creditor["remaining_cents"] == 0:
            creditor_index += 1
        if debtor["remaining_cents"] == 0:
            debtor_index += 1

    return {
        "group": serialize_group(group),
        "balances": balances,
        "settlements": settlements,
    }


@app.get("/")
def root():
    return {"message": "PPM API funcionando"}


@app.post("/auth/register")
def register_user(payload: RegisterInput):
    session = SessionLocal()
    try:
        email = payload.email.strip().lower()
        username = payload.username.strip()
        existing_user = session.query(User).filter(User.email == email).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Ese correo ya esta registrado.")

        user = User(
            username=username,
            email=email,
            password_hash=hash_password(payload.password),
        )
        session.add(user)
        session.commit()
        session.refresh(user)
        return {"user": serialize_user(user)}
    finally:
        session.close()


@app.post("/auth/login")
def login_user(payload: LoginInput):
    session = SessionLocal()
    try:
        email = payload.email.strip().lower()
        user = session.query(User).filter(User.email == email).first()
        if not user or not verify_password(payload.password, user.password_hash):
            raise HTTPException(status_code=401, detail="Credenciales invalidas.")
        return {"user": serialize_user(user)}
    finally:
        session.close()


@app.get("/users")
def list_users():
    session = SessionLocal()
    try:
        users = session.query(User).order_by(User.username.asc()).all()
        return [serialize_user(user) for user in users]
    finally:
        session.close()


@app.get("/users/{user_id}/groups")
def list_user_groups(user_id: int):
    session = SessionLocal()
    try:
        groups = (
            session.query(Group)
            .join(GroupMember, GroupMember.group_id == Group.id)
            .filter(GroupMember.user_id == user_id)
            .options(joinedload(Group.members).joinedload(GroupMember.user))
            .order_by(Group.created_at.desc())
            .all()
        )
        return [serialize_group(group) for group in groups]
    finally:
        session.close()


@app.get("/users/{user_id}/summary")
def get_user_summary(user_id: int):
    session = SessionLocal()
    try:
        user = session.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="Usuario no encontrado.")

        groups = (
            session.query(Group)
            .join(GroupMember, GroupMember.group_id == Group.id)
            .filter(GroupMember.user_id == user_id)
            .options(
                joinedload(Group.expenses).joinedload(Expense.participants).joinedload(ExpenseParticipant.user),
                joinedload(Group.expenses).joinedload(Expense.payer),
                joinedload(Group.members).joinedload(GroupMember.user),
            )
            .all()
        )

        group_ids = [group.id for group in groups]
        total_expenses = 0
        total_paid = 0
        net_balance = 0
        recent_expenses = []

        for group in groups:
            balance_payload = build_group_balance_payload(group)
            user_balance = next((item for item in balance_payload["balances"] if item["user"]["id"] == user_id), None)
            if user_balance:
                net_balance += amount_to_cents(user_balance["net"])
            for expense in group.expenses:
                total_expenses += expense.amount_cents
                if expense.payer_id == user_id:
                    total_paid += expense.amount_cents
                recent_expenses.append(
                    {
                        "group_name": group.name,
                        "description": expense.description,
                        "amount": cents_to_amount(expense.amount_cents),
                        "payer_name": expense.payer.username,
                        "created_at": expense.created_at.isoformat(),
                    }
                )

        recent_expenses.sort(key=lambda item: item["created_at"], reverse=True)

        return {
            "group_count": len(group_ids),
            "total_expenses": cents_to_amount(total_expenses),
            "total_paid": cents_to_amount(total_paid),
            "net_balance": cents_to_amount(net_balance),
            "recent_expenses": recent_expenses[:5],
        }
    finally:
        session.close()


@app.post("/groups")
def create_group(payload: GroupCreateInput):
    session = SessionLocal()
    try:
        creator = session.query(User).filter(User.id == payload.creator_id).first()
        if not creator:
            raise HTTPException(status_code=404, detail="Usuario creador no encontrado.")

        requested_member_ids = set(payload.member_ids)
        requested_member_ids.add(payload.creator_id)
        members = session.query(User).filter(User.id.in_(requested_member_ids)).all()
        if len(members) != len(requested_member_ids):
            raise HTTPException(status_code=400, detail="Hay miembros invalidos en la solicitud.")

        group = Group(
            name=payload.name.strip(),
            description=payload.description.strip(),
            created_by=payload.creator_id,
        )
        session.add(group)
        session.flush()

        for member in members:
            session.add(GroupMember(group_id=group.id, user_id=member.id))

        add_feed_event(
            session,
            group.id,
            creator.id,
            "group_created",
            f"{creator.username} creo el grupo '{group.name}'.",
        )
        session.commit()

        group = (
            session.query(Group)
            .filter(Group.id == group.id)
            .options(joinedload(Group.members).joinedload(GroupMember.user))
            .first()
        )
        return serialize_group(group)
    finally:
        session.close()


@app.get("/groups/{group_id}")
def get_group(group_id: int):
    session = SessionLocal()
    try:
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(joinedload(Group.members).joinedload(GroupMember.user))
            .first()
        )
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")
        return serialize_group(group)
    finally:
        session.close()


@app.post("/groups/{group_id}/members")
def add_group_member(group_id: int, payload: MemberAddInput):
    session = SessionLocal()
    try:
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(joinedload(Group.members).joinedload(GroupMember.user))
            .first()
        )
        user = session.query(User).filter(User.id == payload.user_id).first()
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")
        if not user:
            raise HTTPException(status_code=404, detail="Usuario no encontrado.")
        if any(member.user_id == payload.user_id for member in group.members):
            raise HTTPException(status_code=400, detail="Ese usuario ya pertenece al grupo.")

        session.add(GroupMember(group_id=group_id, user_id=payload.user_id))
        add_feed_event(
            session,
            group_id,
            payload.user_id,
            "member_added",
            f"{user.username} se unio al grupo '{group.name}'.",
        )
        session.commit()

        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(joinedload(Group.members).joinedload(GroupMember.user))
            .first()
        )
        return serialize_group(group)
    finally:
        session.close()


@app.get("/groups/{group_id}/expenses")
def list_group_expenses(group_id: int):
    session = SessionLocal()
    try:
        expenses = (
            session.query(Expense)
            .filter(Expense.group_id == group_id)
            .options(
                joinedload(Expense.payer),
                joinedload(Expense.participants).joinedload(ExpenseParticipant.user),
            )
            .order_by(Expense.created_at.desc())
            .all()
        )
        return [serialize_expense(expense) for expense in expenses]
    finally:
        session.close()


@app.post("/expenses")
def create_expense(payload: ExpenseCreateInput):
    session = SessionLocal()
    try:
        group = (
            session.query(Group)
            .filter(Group.id == payload.group_id)
            .options(joinedload(Group.members).joinedload(GroupMember.user))
            .first()
        )
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")
        if not payload.participant_ids:
            raise HTTPException(status_code=400, detail="Debes elegir al menos un participante.")

        participant_ids = sorted(set(payload.participant_ids))
        validate_group_member_ids(group, participant_ids + [payload.payer_id])

        amount_cents = amount_to_cents(payload.amount)
        expense = Expense(
            group_id=payload.group_id,
            payer_id=payload.payer_id,
            description=payload.description.strip(),
            amount_cents=amount_cents,
        )
        session.add(expense)
        session.flush()

        base_share = amount_cents // len(participant_ids)
        remainder = amount_cents % len(participant_ids)
        for index, participant_id in enumerate(participant_ids):
            share_cents = base_share + (1 if index < remainder else 0)
            session.add(
                ExpenseParticipant(
                    expense_id=expense.id,
                    user_id=participant_id,
                    share_cents=share_cents,
                )
            )

        payer = next(member.user for member in group.members if member.user_id == payload.payer_id)
        add_feed_event(
            session,
            payload.group_id,
            payload.payer_id,
            "expense_created",
            f"{payer.username} registro '{payload.description.strip()}' por ${payload.amount:.2f}.",
        )
        session.commit()

        expense = (
            session.query(Expense)
            .filter(Expense.id == expense.id)
            .options(
                joinedload(Expense.payer),
                joinedload(Expense.participants).joinedload(ExpenseParticipant.user),
            )
            .first()
        )
        return serialize_expense(expense)
    finally:
        session.close()


@app.get("/groups/{group_id}/balances")
def get_group_balances(group_id: int):
    session = SessionLocal()
    try:
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(
                joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Group.expenses).joinedload(Expense.payer),
                joinedload(Group.expenses).joinedload(Expense.participants).joinedload(ExpenseParticipant.user),
            )
            .first()
        )
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")
        return build_group_balance_payload(group)
    finally:
        session.close()


@app.get("/groups/{group_id}/feed")
def get_group_feed(group_id: int):
    session = SessionLocal()
    try:
        events = (
            session.query(FeedEvent)
            .filter(FeedEvent.group_id == group_id)
            .options(joinedload(FeedEvent.actor))
            .order_by(FeedEvent.created_at.desc())
            .limit(50)
            .all()
        )
        return [
            {
                "id": event.id,
                "event_type": event.event_type,
                "message": event.message,
                "created_at": event.created_at.isoformat(),
                "actor": serialize_user(event.actor) if event.actor else None,
            }
            for event in events
        ]
    finally:
        session.close()


if WEB_DIR.exists():
    app.mount("/app", StaticFiles(directory=WEB_DIR, html=True), name="web-app")
