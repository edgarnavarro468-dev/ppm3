from collections import defaultdict
from collections import deque
from decimal import Decimal, ROUND_HALF_UP
from datetime import datetime
from pathlib import Path
import random
import string
from time import time
from urllib.parse import urlparse

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from sqlalchemy.orm import joinedload

from backend.database import (
    Expense,
    ExpenseParticipant,
    FeedEvent,
    Group,
    GroupDecision,
    GroupDecisionVote,
    GroupMember,
    Proposal,
    ProposalVote,
    SessionLocal,
    Settlement,
    User,
    UserContact,
    UserRating,
)
from backend.security import hash_password, verify_password


app = FastAPI(title="PPM Finanzas Sociales API")
WEB_DIR = Path(__file__).resolve().parent.parent / "web"
MAX_AMOUNT_CENTS = 100000000
ALLOWED_ACTIVITIES = {"comida", "actividad", "lugar"}
ALLOWED_CONFIRMATION = {"pendiente", "confirmado", "cancelado"}
ALLOWED_DECISION_MODES = {"majority", "all"}
ALLOWED_GROUP_AUTO_ACTIONS = {"none", "suspend", "delete"}
RATE_LIMIT_BUCKETS: dict[str, deque[float]] = defaultdict(deque)
RATE_LIMIT_RULES = {
    "auth_login": (8, 60),
    "auth_register": (4, 600),
    "user_search": (45, 60),
    "contact_add": (20, 60),
    "profile_update": (12, 300),
    "group_create": (8, 300),
    "expense_create": (20, 60),
    "settlement_create": (16, 60),
    "proposal_create": (12, 120),
}

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; "
        "img-src 'self' https: data:; "
        "style-src 'self' 'unsafe-inline'; "
        "script-src 'self'; "
        "connect-src 'self'; "
        "frame-ancestors 'none'; "
        "base-uri 'self'; "
        "form-action 'self'"
    )
    return response


class RegisterInput(BaseModel):
    username: str = Field(min_length=2, max_length=120)
    first_name: str = Field(default="", max_length=120)
    last_name: str = Field(default="", max_length=120)
    email: str
    phone_number: str = Field(default="", max_length=40)
    avatar_url: str = Field(default="", max_length=500)
    password: str = Field(min_length=8, max_length=120)
    website: str = ""
    form_started_at: float = 0


class LoginInput(BaseModel):
    email: str
    password: str
    website: str = ""
    form_started_at: float = 0


class GroupCreateInput(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    description: str = ""
    creator_id: int
    member_ids: list[int] = []
    ends_at: str = ""
    auto_close_action: str = "none"


class MemberAddInput(BaseModel):
    user_id: int


class ExpenseCreateInput(BaseModel):
    group_id: int
    payer_id: int
    description: str = Field(min_length=2, max_length=255)
    amount: float = Field(gt=0)
    participant_ids: list[int]


class ProposalCreateInput(BaseModel):
    creator_id: int
    title: str = Field(min_length=2, max_length=160)
    details: str = ""
    activity_type: str = "actividad"
    availability_text: str = ""
    provider_name: str = ""
    provider_details: str = ""
    provider_url: str = ""
    payer_user_id: int | None = None
    payment_due_date: str = ""
    scheduled_for_date: str = ""
    vote_deadline: str = ""
    total_amount: float = Field(gt=0)
    payment_method: str = ""
    confirmation_status: str = "pendiente"
    is_shared_debt: bool = True


class ProposalVoteInput(BaseModel):
    user_id: int


class ProposalSelectInput(BaseModel):
    user_id: int


class SettlementCreateInput(BaseModel):
    actor_id: int
    from_user_id: int
    to_user_id: int
    amount: float = Field(gt=0)
    notes: str = ""


class SettlementConfirmInput(BaseModel):
    actor_id: int


class RatingCreateInput(BaseModel):
    rater_id: int
    rated_user_id: int
    score: int = Field(ge=1, le=5)
    title: str = Field(min_length=2, max_length=80)
    comment: str = ""


class DecisionVoteInput(BaseModel):
    user_id: int
    mode: str = "majority"


class ProfileUpdateInput(BaseModel):
    username: str = Field(min_length=2, max_length=120)
    first_name: str = Field(default="", max_length=120)
    last_name: str = Field(default="", max_length=120)
    phone_number: str = Field(default="", max_length=40)
    avatar_url: str = Field(default="", max_length=500)


class ContactCreateInput(BaseModel):
    contact_user_id: int
    nickname: str = Field(default="", max_length=120)


def amount_to_cents(amount: float) -> int:
    decimal_amount = Decimal(str(amount)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return int(decimal_amount * 100)


def cents_to_amount(value: int) -> float:
    return float((Decimal(value) / Decimal("100")).quantize(Decimal("0.01")))


def enforce_amount_limit(amount_cents: int, label: str = "El monto") -> None:
    if amount_cents > MAX_AMOUNT_CENTS:
        raise HTTPException(status_code=400, detail=f"{label} no puede superar 1,000,000 MXN.")


def validate_decision_mode(mode: str) -> str:
    normalized = (mode or "majority").strip().lower()
    if normalized not in ALLOWED_DECISION_MODES:
        raise HTTPException(status_code=400, detail="Modo de votacion invalido.")
    return normalized


def validate_activity_type(activity_type: str) -> str:
    normalized = (activity_type or "actividad").strip().lower()
    if normalized not in ALLOWED_ACTIVITIES:
        raise HTTPException(status_code=400, detail="Tipo de actividad invalido.")
    return normalized


def validate_confirmation_status(status: str) -> str:
    normalized = (status or "pendiente").strip().lower()
    if normalized not in ALLOWED_CONFIRMATION:
        raise HTTPException(status_code=400, detail="Estado de confirmacion invalido.")
    return normalized


def validate_group_auto_action(action: str) -> str:
    normalized = (action or "none").strip().lower()
    if normalized not in ALLOWED_GROUP_AUTO_ACTIONS:
        raise HTTPException(status_code=400, detail="Accion de cierre de grupo invalida.")
    return normalized


def normalize_datetime_string(value: str) -> str:
    return (value or "").strip()


def parse_datetime_string(value: str) -> datetime | None:
    normalized = normalize_datetime_string(value)
    if not normalized:
        return None
    try:
        return datetime.fromisoformat(normalized)
    except ValueError:
        return None


def validate_optional_url(value: str) -> str:
    normalized = (value or "").strip()
    if not normalized:
        return ""
    parsed = urlparse(normalized)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise HTTPException(status_code=400, detail="La URL debe empezar con http:// o https:// y ser valida.")
    return normalized[:500]


def majority_threshold(member_count: int) -> int:
    return (member_count // 2) + 1


def decision_threshold(member_count: int, mode: str) -> int:
    if mode == "all":
        return member_count
    return majority_threshold(member_count)


def rating_badge(score: float) -> str:
    if score >= 4.8:
        return "Socio leyenda"
    if score >= 4.2:
        return "Pagador confiable"
    if score >= 3.5:
        return "Buen aliado"
    if score >= 2.5:
        return "En observacion"
    return "Modo fantasma"


def clean_name(value: str) -> str:
    return (value or "").strip()


def clean_phone(value: str) -> str:
    raw = "".join(character for character in (value or "").strip() if character.isdigit() or character in "+-() ")
    digits = "".join(character for character in raw if character.isdigit())
    if digits and len(digits) < 7:
        raise HTTPException(status_code=400, detail="El telefono parece demasiado corto.")
    return raw[:40]


def clean_avatar_url(value: str) -> str:
    return validate_optional_url(value)


def validate_password_strength(value: str) -> str:
    password = value or ""
    has_letter = any(character.isalpha() for character in password)
    has_digit = any(character.isdigit() for character in password)
    if len(password) < 8 or not has_letter or not has_digit:
        raise HTTPException(
            status_code=400,
            detail="La contrasena debe tener al menos 8 caracteres e incluir letras y numeros.",
        )
    return password


def client_ip(request: Request) -> str:
    forwarded_for = request.headers.get("x-forwarded-for", "").split(",")[0].strip()
    if forwarded_for:
        return forwarded_for
    return request.client.host if request.client else "unknown"


def enforce_rate_limit(request: Request, action: str) -> None:
    limit, window_seconds = RATE_LIMIT_RULES[action]
    bucket_key = f"{action}:{client_ip(request)}"
    bucket = RATE_LIMIT_BUCKETS[bucket_key]
    now = time()

    while bucket and now - bucket[0] > window_seconds:
        bucket.popleft()

    if len(bucket) >= limit:
        raise HTTPException(status_code=429, detail="Se detectaron demasiados intentos. Espera un momento.")

    bucket.append(now)


def enforce_honeypot(payload) -> None:
    if getattr(payload, "website", "").strip():
        raise HTTPException(status_code=400, detail="Solicitud rechazada.")

    form_started_at = float(getattr(payload, "form_started_at", 0) or 0)
    if form_started_at and (time() - form_started_at) < 1.2:
        raise HTTPException(status_code=400, detail="Envio demasiado rapido. Intenta de nuevo.")


def display_name_for_user(user: User) -> str:
    full_name = " ".join(part for part in [(user.first_name or "").strip(), (user.last_name or "").strip()] if part).strip()
    return full_name or user.username


def normalize_user_code(value: str) -> str:
    normalized = (value or "").strip().upper().replace(" ", "")
    if normalized and not normalized.startswith("PPM-") and normalized.replace("-", "").isalnum():
        normalized = f"PPM-{normalized.replace('-', '')}"
    return normalized


def public_code_for_user(user: User) -> str:
    code = (getattr(user, "public_code", "") or "").strip().upper()
    return code or f"PPM-{user.id:06d}"


def generate_user_public_code(session) -> str:
    alphabet = string.ascii_uppercase + string.digits
    while True:
        suffix = "".join(random.choice(alphabet) for _ in range(6))
        code = f"PPM-{suffix}"
        exists = session.query(User).filter(User.public_code == code).first()
        if not exists:
            return code


def ensure_user_public_codes(session) -> None:
    users = session.query(User).filter((User.public_code == "") | (User.public_code.is_(None))).all()
    if not users:
        return
    for user in users:
        user.public_code = generate_user_public_code(session)
    session.commit()


def serialize_user(user: User) -> dict:
    full_name = " ".join(part for part in [(user.first_name or "").strip(), (user.last_name or "").strip()] if part).strip()
    return {
        "id": user.id,
        "public_code": public_code_for_user(user),
        "invite_code": public_code_for_user(user),
        "username": user.username,
        "email": user.email,
        "first_name": user.first_name or "",
        "last_name": user.last_name or "",
        "full_name": full_name,
        "display_name": full_name or user.username,
        "phone_number": user.phone_number or "",
        "avatar_url": user.avatar_url or "",
    }


def serialize_group_member(membership: GroupMember) -> dict:
    data = serialize_user(membership.user)
    role = (membership.role or "member").strip().lower()
    if membership.group and membership.group.created_by == membership.user_id:
        role = "host"
    data["group_role"] = role
    data["membership_status"] = (membership.status or "active").strip().lower()
    return data


def serialize_contact(contact: UserContact) -> dict:
    return {
        "id": contact.id,
        "nickname": contact.nickname,
        "created_at": contact.created_at.isoformat(),
        "user": serialize_user(contact.contact_user),
    }


def serialize_decision(decision: GroupDecision | None, member_count: int) -> dict | None:
    if not decision:
        return None
    threshold = decision_threshold(member_count, decision.mode)
    return {
        "id": decision.id,
        "decision_type": decision.decision_type,
        "mode": decision.mode,
        "status": decision.status,
        "vote_count": len(decision.votes),
        "threshold": threshold,
        "requested_by": serialize_user(decision.requester),
    }


def serialize_group(group: Group) -> dict:
    members = sorted(
        [membership for membership in group.members if (membership.status or "active") == "active"],
        key=lambda membership: membership.user.username.lower(),
    )
    delete_decision = next(
        (decision for decision in group.decisions if decision.decision_type == "group_delete" and decision.status == "open"),
        None,
    )
    net_totals = defaultdict(int)
    for member in members:
        net_totals[member.user_id] = 0
    for expense in getattr(group, "expenses", []) or []:
        net_totals[expense.payer_id] += expense.amount_cents
        for participant in expense.participants:
            net_totals[participant.user_id] -= participant.share_cents
    for settlement in getattr(group, "settlements", []) or []:
        net_totals[settlement.from_user_id] += settlement.amount_cents
        net_totals[settlement.to_user_id] -= settlement.amount_cents
    pending_member_count = len([amount for amount in net_totals.values() if amount < 0])
    settled_member_count = len([amount for amount in net_totals.values() if amount == 0])
    payment_status = "sin_movimientos"
    if not getattr(group, "expenses", []) and not getattr(group, "settlements", []):
        payment_status = "sin_movimientos"
    elif pending_member_count:
        payment_status = "pendientes"
    else:
        payment_status = "pagado"
    return {
        "id": group.id,
        "name": group.name,
        "description": group.description,
        "status": group.status,
        "ends_at": group.ends_at,
        "auto_close_action": group.auto_close_action,
        "created_by": group.created_by,
        "created_at": group.created_at.isoformat(),
        "host": serialize_user(group.creator),
        "members": [serialize_group_member(member) for member in members],
        "member_count": len(members),
        "payment_status": payment_status,
        "pending_member_count": pending_member_count,
        "settled_member_count": settled_member_count,
        "active_group_delete_vote": serialize_decision(delete_decision, len(members)),
    }


def serialize_expense(expense: Expense, member_count: int, delete_decision: GroupDecision | None = None) -> dict:
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
        "delete_vote": serialize_decision(delete_decision, member_count),
    }


def serialize_proposal(proposal: Proposal, member_count: int) -> dict:
    return {
        "id": proposal.id,
        "group_id": proposal.group_id,
        "creator": serialize_user(proposal.creator),
        "payer_user": serialize_user(proposal.payer_user) if proposal.payer_user else None,
        "title": proposal.title,
        "details": proposal.details,
        "activity_type": proposal.activity_type,
        "availability_text": proposal.availability_text,
        "provider_name": proposal.provider_name,
        "provider_details": proposal.provider_details,
        "provider_url": proposal.provider_url,
        "payment_due_date": proposal.payment_due_date,
        "scheduled_for_date": proposal.scheduled_for_date,
        "vote_deadline": proposal.vote_deadline,
        "total_amount": cents_to_amount(proposal.total_amount_cents),
        "payment_method": proposal.payment_method,
        "confirmation_status": proposal.confirmation_status,
        "is_shared_debt": proposal.is_shared_debt,
        "status": proposal.status,
        "created_at": proposal.created_at.isoformat(),
        "vote_count": len(proposal.votes),
        "vote_threshold": majority_threshold(member_count),
        "voters": [serialize_user(vote.user) for vote in proposal.votes],
    }


def serialize_settlement(settlement: Settlement) -> dict:
    return {
        "id": settlement.id,
        "group_id": settlement.group_id,
        "from_user": serialize_user(settlement.from_user),
        "to_user": serialize_user(settlement.to_user),
        "amount": cents_to_amount(settlement.amount_cents),
        "notes": settlement.notes,
        "received_confirmed": settlement.received_confirmed,
        "from_confirmed": settlement.from_confirmed,
        "to_confirmed": settlement.to_confirmed,
        "received_confirmed_at": settlement.received_confirmed_at,
        "received_confirmed_by": serialize_user(settlement.confirmer) if settlement.confirmer else None,
        "created_by": serialize_user(settlement.creator),
        "created_at": settlement.created_at.isoformat(),
    }


def serialize_rating_entry(rating: UserRating) -> dict:
    return {
        "id": rating.id,
        "score": rating.score,
        "title": rating.title,
        "comment": rating.comment,
        "created_at": rating.created_at.isoformat(),
        "rater": serialize_user(rating.rater),
        "rated_user": serialize_user(rating.rated_user),
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
    group_member_ids = {member.user_id for member in group.members if (member.status or "active") == "active"}
    invalid_ids = [user_id for user_id in user_ids if user_id not in group_member_ids]
    if invalid_ids:
        raise HTTPException(status_code=400, detail="Hay usuarios que no pertenecen al grupo.")


def ensure_group_member(group: Group, user_id: int) -> None:
    if not any(member.user_id == user_id and (member.status or "active") == "active" for member in group.members):
        raise HTTPException(status_code=403, detail="Ese usuario no pertenece al grupo.")


def ensure_group_host(group: Group, user_id: int) -> None:
    if group.created_by != user_id:
        raise HTTPException(status_code=403, detail="Solo el anfitrion del grupo puede hacer eso.")


def ensure_group_active(group: Group) -> None:
    if group.status != "active":
        raise HTTPException(status_code=400, detail="Este grupo esta suspendido o cerrado y ya no admite cambios.")


def sync_group_lifecycle(session) -> None:
    groups = session.query(Group).all()
    now = datetime.utcnow()
    changed = False

    for group in groups:
        if group.status != "active":
            continue
        ends_at = parse_datetime_string(group.ends_at)
        if not ends_at or ends_at > now:
            continue

        action = validate_group_auto_action(group.auto_close_action)
        if action == "delete":
            session.delete(group)
            changed = True
            continue
        if action == "suspend":
            group.status = "suspended"
            changed = True

    if changed:
        session.commit()


def build_group_balance_payload(group: Group) -> dict:
    paid_totals = defaultdict(int)
    owed_totals = defaultdict(int)
    net_totals = defaultdict(int)
    settled_out = defaultdict(int)
    settled_in = defaultdict(int)

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

    for settlement in group.settlements:
        net_totals[settlement.from_user_id] += settlement.amount_cents
        net_totals[settlement.to_user_id] -= settlement.amount_cents
        settled_out[settlement.from_user_id] += settlement.amount_cents
        settled_in[settlement.to_user_id] += settlement.amount_cents

    balances = []
    for member in sorted(group.members, key=lambda item: item.user.username.lower()):
        user_id = member.user_id
        balances.append(
            {
                "user": serialize_user(member.user),
                "paid": cents_to_amount(paid_totals[user_id]),
                "owed": cents_to_amount(owed_totals[user_id]),
                "settled_out": cents_to_amount(settled_out[user_id]),
                "settled_in": cents_to_amount(settled_in[user_id]),
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


def build_ratings_payload(group: Group) -> dict:
    rating_entries = [serialize_rating_entry(rating) for rating in sorted(group.ratings, key=lambda item: item.created_at, reverse=True)]
    leaderboard_map = {}

    for rating in group.ratings:
        bucket = leaderboard_map.setdefault(
            rating.rated_user_id,
            {
                "user": serialize_user(rating.rated_user),
                "score_total": 0,
                "count": 0,
                "custom_titles": [],
            },
        )
        bucket["score_total"] += rating.score
        bucket["count"] += 1
        if rating.title and rating.title not in bucket["custom_titles"]:
            bucket["custom_titles"].append(rating.title)

    leaderboard = []
    for item in leaderboard_map.values():
        average_score = item["score_total"] / item["count"]
        leaderboard.append(
            {
                "user": item["user"],
                "average_score": round(average_score, 2),
                "rating_count": item["count"],
                "badge_title": rating_badge(average_score),
                "custom_titles": item["custom_titles"][:3],
            }
        )

    leaderboard.sort(key=lambda item: (-item["average_score"], -item["rating_count"], item["user"]["username"].lower()))
    return {
        "leaderboard": leaderboard,
        "ratings": rating_entries,
    }


def build_group_stats_payload(group: Group) -> dict:
    spend_by_user = defaultdict(int)
    activity_breakdown = defaultdict(int)
    proposal_vote_map = defaultdict(int)

    for expense in group.expenses:
        spend_by_user[expense.payer.username] += expense.amount_cents

    for proposal in group.proposals:
        activity_breakdown[proposal.activity_type] += 1
        proposal_vote_map[proposal.title] += len(proposal.votes)

    selected_proposal = next((proposal for proposal in group.proposals if proposal.status == "selected"), None)
    ratings_payload = build_ratings_payload(group)

    spend_rows = [
        {"label": name, "amount": cents_to_amount(amount)}
        for name, amount in sorted(spend_by_user.items(), key=lambda item: item[1], reverse=True)
    ]
    proposal_rows = [
        {"label": name, "votes": votes}
        for name, votes in sorted(proposal_vote_map.items(), key=lambda item: item[1], reverse=True)
    ]
    activity_rows = [
        {"label": activity, "count": count}
        for activity, count in sorted(activity_breakdown.items(), key=lambda item: item[1], reverse=True)
    ]

    return {
        "expense_count": len(group.expenses),
        "proposal_count": len(group.proposals),
        "settlement_count": len(group.settlements),
        "selected_proposal": serialize_proposal(selected_proposal, len(group.members)) if selected_proposal else None,
        "spend_by_user": spend_rows,
        "proposal_votes": proposal_rows,
        "activity_breakdown": activity_rows,
        "top_rated_users": ratings_payload["leaderboard"][:5],
    }


@app.get("/")
def root():
    return {"message": "PPM API funcionando"}


@app.post("/auth/register")
def register_user(payload: RegisterInput, request: Request):
    session = SessionLocal()
    try:
        enforce_rate_limit(request, "auth_register")
        enforce_honeypot(payload)
        email = payload.email.strip().lower()
        username = payload.username.strip()
        existing_user = session.query(User).filter(User.email == email).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Ese correo ya esta registrado.")

        user = User(
            username=username,
            first_name=clean_name(payload.first_name),
            last_name=clean_name(payload.last_name),
            email=email,
            public_code=generate_user_public_code(session),
            phone_number=clean_phone(payload.phone_number),
            avatar_url=clean_avatar_url(payload.avatar_url),
            password_hash=hash_password(validate_password_strength(payload.password)),
        )
        session.add(user)
        session.commit()
        session.refresh(user)
        return {"user": serialize_user(user)}
    finally:
        session.close()


@app.post("/auth/login")
def login_user(payload: LoginInput, request: Request):
    session = SessionLocal()
    try:
        enforce_rate_limit(request, "auth_login")
        enforce_honeypot(payload)
        email = payload.email.strip().lower()
        user = session.query(User).filter(User.email == email).first()
        if not user or not verify_password(payload.password, user.password_hash):
            raise HTTPException(status_code=401, detail="Credenciales invalidas.")
        if not (user.public_code or "").strip():
            user.public_code = generate_user_public_code(session)
            session.commit()
            session.refresh(user)
        return {"user": serialize_user(user)}
    finally:
        session.close()


@app.get("/users")
def list_users(request: Request, q: str = Query(default="", max_length=120)):
    session = SessionLocal()
    try:
        enforce_rate_limit(request, "user_search")
        ensure_user_public_codes(session)
        query_text = (q or "").strip().lower()
        query_code = normalize_user_code(q).lower()
        users = session.query(User).order_by(User.username.asc()).all()
        if query_text:
            users = [
                user
                for user in users
                if query_text in user.username.lower()
                or query_text in user.email.lower()
                or query_text == str(user.id)
                or query_text in public_code_for_user(user).lower()
                or query_code == public_code_for_user(user).lower()
                or query_text in (user.first_name or "").lower()
                or query_text in (user.last_name or "").lower()
                or query_text in display_name_for_user(user).lower()
                or query_text in (user.phone_number or "").lower()
            ]
        return [serialize_user(user) for user in users]
    finally:
        session.close()


@app.patch("/users/{user_id}")
def update_user_profile(user_id: int, payload: ProfileUpdateInput, request: Request):
    session = SessionLocal()
    try:
        enforce_rate_limit(request, "profile_update")
        user = session.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="Usuario no encontrado.")

        user.username = payload.username.strip()
        user.first_name = clean_name(payload.first_name)
        user.last_name = clean_name(payload.last_name)
        user.phone_number = clean_phone(payload.phone_number)
        user.avatar_url = clean_avatar_url(payload.avatar_url)
        session.commit()
        session.refresh(user)
        return {"user": serialize_user(user)}
    finally:
        session.close()


@app.get("/users/{user_id}/contacts")
def list_user_contacts(user_id: int):
    session = SessionLocal()
    try:
        user = session.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="Usuario no encontrado.")

        contacts = (
            session.query(UserContact)
            .filter(UserContact.owner_user_id == user_id)
            .options(joinedload(UserContact.contact_user))
            .order_by(UserContact.nickname.asc(), UserContact.created_at.desc())
            .all()
        )
        return [serialize_contact(contact) for contact in contacts]
    finally:
        session.close()


@app.post("/users/{user_id}/contacts")
def create_user_contact(user_id: int, payload: ContactCreateInput, request: Request):
    session = SessionLocal()
    try:
        enforce_rate_limit(request, "contact_add")
        owner = session.query(User).filter(User.id == user_id).first()
        contact_user = session.query(User).filter(User.id == payload.contact_user_id).first()
        if not owner:
            raise HTTPException(status_code=404, detail="Usuario no encontrado.")
        if not contact_user:
            raise HTTPException(status_code=404, detail="Perfil a guardar no encontrado.")
        if user_id == payload.contact_user_id:
            raise HTTPException(status_code=400, detail="No puedes agregarte a ti mismo como conocido.")

        existing_contact = (
            session.query(UserContact)
            .filter(
                UserContact.owner_user_id == user_id,
                UserContact.contact_user_id == payload.contact_user_id,
            )
            .first()
        )

        nickname = clean_name(payload.nickname)
        if existing_contact:
            existing_contact.nickname = nickname
            session.commit()
            session.refresh(existing_contact)
            return {"contact": serialize_contact(existing_contact), "updated": True}

        contact = UserContact(
            owner_user_id=user_id,
            contact_user_id=payload.contact_user_id,
            nickname=nickname,
        )
        session.add(contact)
        session.commit()
        session.refresh(contact)
        contact = (
            session.query(UserContact)
            .filter(UserContact.id == contact.id)
            .options(joinedload(UserContact.contact_user))
            .first()
        )
        return {"contact": serialize_contact(contact), "updated": False}
    finally:
        session.close()


@app.get("/users/{user_id}/groups")
def list_user_groups(user_id: int):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        groups = (
            session.query(Group)
            .join(GroupMember, GroupMember.group_id == Group.id)
            .filter(GroupMember.user_id == user_id, GroupMember.status == "active")
            .options(
                joinedload(Group.creator),
                joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Group.expenses).joinedload(Expense.participants),
                joinedload(Group.settlements),
                joinedload(Group.decisions).joinedload(GroupDecision.votes),
                joinedload(Group.decisions).joinedload(GroupDecision.requester),
            )
            .order_by(Group.created_at.desc())
            .all()
        )
        return [serialize_group(group) for group in groups]
    finally:
        session.close()


@app.get("/users/{user_id}/invitations")
def list_user_invitations(user_id: int):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        invitations = (
            session.query(Group)
            .join(GroupMember, GroupMember.group_id == Group.id)
            .filter(GroupMember.user_id == user_id, GroupMember.status == "pending")
            .options(
                joinedload(Group.creator),
                joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Group.decisions).joinedload(GroupDecision.votes),
                joinedload(Group.decisions).joinedload(GroupDecision.requester),
            )
            .order_by(Group.created_at.desc())
            .all()
        )
        return [serialize_group(group) for group in invitations]
    finally:
        session.close()


@app.get("/users/{user_id}/summary")
def get_user_summary(user_id: int):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        user = session.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="Usuario no encontrado.")

        groups = (
            session.query(Group)
            .join(GroupMember, GroupMember.group_id == Group.id)
            .filter(GroupMember.user_id == user_id, GroupMember.status == "active")
            .options(
                joinedload(Group.creator),
                joinedload(Group.expenses).joinedload(Expense.participants).joinedload(ExpenseParticipant.user),
                joinedload(Group.expenses).joinedload(Expense.payer),
                joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Group.settlements).joinedload(Settlement.from_user),
                joinedload(Group.settlements).joinedload(Settlement.to_user),
                joinedload(Group.proposals).joinedload(Proposal.votes),
            )
            .all()
        )

        total_expenses = 0
        total_paid = 0
        net_balance = 0
        total_settlements = 0
        total_proposals = 0
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
            total_settlements += len(group.settlements)
            total_proposals += len(group.proposals)

        recent_expenses.sort(key=lambda item: item["created_at"], reverse=True)

        return {
            "group_count": len(groups),
            "total_expenses": cents_to_amount(total_expenses),
            "total_paid": cents_to_amount(total_paid),
            "net_balance": cents_to_amount(net_balance),
            "settlement_count": total_settlements,
            "proposal_count": total_proposals,
            "recent_expenses": recent_expenses[:8],
        }
    finally:
        session.close()


@app.post("/groups")
def create_group(payload: GroupCreateInput, request: Request):
    session = SessionLocal()
    try:
        enforce_rate_limit(request, "group_create")
        creator = session.query(User).filter(User.id == payload.creator_id).first()
        if not creator:
            raise HTTPException(status_code=404, detail="Usuario creador no encontrado.")
        if payload.ends_at and not parse_datetime_string(payload.ends_at):
            raise HTTPException(status_code=400, detail="La fecha final del grupo no es valida.")

        requested_member_ids = set(payload.member_ids)
        requested_member_ids.add(payload.creator_id)
        members = session.query(User).filter(User.id.in_(requested_member_ids)).all()
        if len(members) != len(requested_member_ids):
            raise HTTPException(status_code=400, detail="Hay miembros invalidos en la solicitud.")

        group = Group(
            name=payload.name.strip(),
            description=payload.description.strip(),
            created_by=payload.creator_id,
            ends_at=normalize_datetime_string(payload.ends_at),
            auto_close_action=validate_group_auto_action(payload.auto_close_action),
        )
        session.add(group)
        session.flush()

        for member in members:
            is_creator = member.id == payload.creator_id
            session.add(
                GroupMember(
                    group_id=group.id,
                    user_id=member.id,
                    role="host" if is_creator else "member",
                    status="active" if is_creator else "pending",
                )
            )

        add_feed_event(
            session,
            group.id,
            creator.id,
            "group_created",
            f"{creator.username} creo el grupo '{group.name}' y quedo como anfitrion.",
        )
        for member in members:
            if member.id != payload.creator_id:
                add_feed_event(
                    session,
                    group.id,
                    creator.id,
                    "member_invited",
                    f"{creator.username} invito a {member.username} al grupo '{group.name}'.",
                )
        session.commit()

        group = (
            session.query(Group)
            .filter(Group.id == group.id)
            .options(
                joinedload(Group.creator),
                joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Group.decisions).joinedload(GroupDecision.votes),
                joinedload(Group.decisions).joinedload(GroupDecision.requester),
            )
            .first()
        )
        return serialize_group(group)
    finally:
        session.close()


@app.get("/groups/{group_id}")
def get_group(group_id: int):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(
                joinedload(Group.creator),
                joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Group.expenses).joinedload(Expense.participants),
                joinedload(Group.settlements),
                joinedload(Group.decisions).joinedload(GroupDecision.votes),
                joinedload(Group.decisions).joinedload(GroupDecision.requester),
            )
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
        sync_group_lifecycle(session)
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(
                joinedload(Group.creator),
                joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Group.decisions).joinedload(GroupDecision.votes),
                joinedload(Group.decisions).joinedload(GroupDecision.requester),
            )
            .first()
        )
        user = session.query(User).filter(User.id == payload.user_id).first()
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")
        ensure_group_active(group)
        if not user:
            raise HTTPException(status_code=404, detail="Usuario no encontrado.")
        existing_member = next((member for member in group.members if member.user_id == payload.user_id), None)
        if existing_member and (existing_member.status or "active") == "active":
            raise HTTPException(status_code=400, detail="Ese usuario ya pertenece al grupo.")
        if existing_member and existing_member.status == "pending":
            raise HTTPException(status_code=400, detail="Ese usuario ya tiene una invitacion pendiente.")

        session.add(GroupMember(group_id=group_id, user_id=payload.user_id, role="member", status="pending"))
        add_feed_event(
            session,
            group_id,
            payload.user_id,
            "member_invited",
            f"{user.username} recibio una invitacion para unirse al grupo '{group.name}'.",
        )
        session.commit()

        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(
                joinedload(Group.creator),
                joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Group.decisions).joinedload(GroupDecision.votes),
                joinedload(Group.decisions).joinedload(GroupDecision.requester),
            )
            .first()
        )
        return serialize_group(group)
    finally:
        session.close()


@app.post("/groups/{group_id}/members/{user_id}/accept")
def accept_group_invitation(group_id: int, user_id: int):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(
                joinedload(Group.creator),
                joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Group.decisions).joinedload(GroupDecision.votes),
                joinedload(Group.decisions).joinedload(GroupDecision.requester),
            )
            .first()
        )
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")
        ensure_group_active(group)
        membership = next((member for member in group.members if member.user_id == user_id), None)
        if not membership:
            raise HTTPException(status_code=404, detail="Invitacion no encontrada.")
        if (membership.status or "active") == "active":
            raise HTTPException(status_code=400, detail="Ya perteneces a este grupo.")

        membership.status = "active"
        add_feed_event(
            session,
            group_id,
            user_id,
            "member_joined",
            f"{membership.user.username} acepto la invitacion y se unio al grupo '{group.name}'.",
        )
        session.commit()
        session.refresh(group)
        return serialize_group(group)
    finally:
        session.close()


@app.get("/groups/{group_id}/expenses")
def list_group_expenses(group_id: int):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(
                joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Group.decisions).joinedload(GroupDecision.votes),
                joinedload(Group.decisions).joinedload(GroupDecision.requester),
            )
            .first()
        )
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")

        decision_map = {
            decision.target_expense_id: decision
            for decision in group.decisions
            if decision.decision_type == "expense_delete" and decision.status == "open" and decision.target_expense_id
        }
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
        return [serialize_expense(expense, len(group.members), decision_map.get(expense.id)) for expense in expenses]
    finally:
        session.close()


@app.post("/expenses")
def create_expense(payload: ExpenseCreateInput, request: Request):
    session = SessionLocal()
    try:
        enforce_rate_limit(request, "expense_create")
        sync_group_lifecycle(session)
        group = (
            session.query(Group)
            .filter(Group.id == payload.group_id)
            .options(joinedload(Group.members).joinedload(GroupMember.user))
            .first()
        )
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")
        ensure_group_active(group)
        if not payload.participant_ids:
            raise HTTPException(status_code=400, detail="Debes elegir al menos un participante.")

        participant_ids = sorted(set(payload.participant_ids))
        validate_group_member_ids(group, participant_ids + [payload.payer_id])

        amount_cents = amount_to_cents(payload.amount)
        enforce_amount_limit(amount_cents, "El gasto")

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
        return serialize_expense(expense, len(group.members))
    finally:
        session.close()


@app.post("/expenses/{expense_id}/delete-vote")
def vote_delete_expense(expense_id: int, payload: DecisionVoteInput):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        expense = (
            session.query(Expense)
            .filter(Expense.id == expense_id)
            .options(joinedload(Expense.group).joinedload(Group.members).joinedload(GroupMember.user))
            .first()
        )
        if not expense:
            raise HTTPException(status_code=404, detail="Gasto no encontrado.")

        group = expense.group
        ensure_group_member(group, payload.user_id)
        mode = validate_decision_mode(payload.mode)

        decision = (
            session.query(GroupDecision)
            .filter(
                GroupDecision.group_id == group.id,
                GroupDecision.decision_type == "expense_delete",
                GroupDecision.target_expense_id == expense_id,
                GroupDecision.status == "open",
            )
            .options(joinedload(GroupDecision.votes), joinedload(GroupDecision.requester))
            .first()
        )
        if not decision:
            decision = GroupDecision(
                group_id=group.id,
                requested_by=payload.user_id,
                decision_type="expense_delete",
                target_expense_id=expense_id,
                mode=mode,
            )
            session.add(decision)
            session.flush()

        if any(vote.user_id == payload.user_id for vote in decision.votes):
            raise HTTPException(status_code=400, detail="Ese usuario ya voto en esta decision.")

        session.add(GroupDecisionVote(decision_id=decision.id, user_id=payload.user_id))
        session.flush()
        session.refresh(decision)

        threshold = decision_threshold(len(group.members), decision.mode)
        vote_count = len(decision.votes)
        if vote_count >= threshold:
            description = expense.description
            session.delete(decision)
            session.delete(expense)
            add_feed_event(
                session,
                group.id,
                payload.user_id,
                "expense_deleted",
                f"Se elimino por votacion la deuda compartida '{description}'.",
            )
            session.commit()
            return {"approved": True, "deleted": True}

        add_feed_event(
            session,
            group.id,
            payload.user_id,
            "expense_delete_vote",
            f"Se registro un voto para eliminar la deuda '{expense.description}'.",
        )
        session.commit()
        return {
            "approved": False,
            "deleted": False,
            "vote_count": vote_count,
            "threshold": threshold,
            "mode": decision.mode,
        }
    finally:
        session.close()


@app.post("/groups/{group_id}/delete-vote")
def vote_delete_group(group_id: int, payload: DecisionVoteInput):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(joinedload(Group.members).joinedload(GroupMember.user))
            .first()
        )
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")

        ensure_group_member(group, payload.user_id)
        mode = validate_decision_mode(payload.mode)

        decision = (
            session.query(GroupDecision)
            .filter(
                GroupDecision.group_id == group.id,
                GroupDecision.decision_type == "group_delete",
                GroupDecision.status == "open",
            )
            .options(joinedload(GroupDecision.votes), joinedload(GroupDecision.requester))
            .first()
        )
        if not decision:
            decision = GroupDecision(
                group_id=group.id,
                requested_by=payload.user_id,
                decision_type="group_delete",
                mode=mode,
            )
            session.add(decision)
            session.flush()

        if any(vote.user_id == payload.user_id for vote in decision.votes):
            raise HTTPException(status_code=400, detail="Ese usuario ya voto en esta decision.")

        session.add(GroupDecisionVote(decision_id=decision.id, user_id=payload.user_id))
        session.flush()
        session.refresh(decision)

        threshold = decision_threshold(len(group.members), decision.mode)
        vote_count = len(decision.votes)
        if vote_count >= threshold:
            session.delete(group)
            session.commit()
            return {"approved": True, "deleted": True}

        add_feed_event(
            session,
            group.id,
            payload.user_id,
            "group_delete_vote",
            f"Se registro un voto para eliminar el grupo '{group.name}'.",
        )
        session.commit()
        return {
            "approved": False,
            "deleted": False,
            "vote_count": vote_count,
            "threshold": threshold,
            "mode": decision.mode,
        }
    finally:
        session.close()


@app.get("/groups/{group_id}/balances")
def get_group_balances(group_id: int):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(
                joinedload(Group.creator),
                joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Group.expenses).joinedload(Expense.payer),
                joinedload(Group.expenses).joinedload(Expense.participants).joinedload(ExpenseParticipant.user),
                joinedload(Group.settlements).joinedload(Settlement.from_user),
                joinedload(Group.settlements).joinedload(Settlement.to_user),
                joinedload(Group.decisions).joinedload(GroupDecision.votes),
                joinedload(Group.decisions).joinedload(GroupDecision.requester),
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
        sync_group_lifecycle(session)
        events = (
            session.query(FeedEvent)
            .filter(FeedEvent.group_id == group_id)
            .options(joinedload(FeedEvent.actor))
            .order_by(FeedEvent.created_at.desc())
            .limit(80)
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


@app.get("/groups/{group_id}/settlements")
def list_group_settlements(group_id: int):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        settlements = (
            session.query(Settlement)
            .filter(Settlement.group_id == group_id)
            .options(
                joinedload(Settlement.from_user),
                joinedload(Settlement.to_user),
                joinedload(Settlement.creator),
                joinedload(Settlement.confirmer),
            )
            .order_by(Settlement.created_at.desc())
            .all()
        )
        return [serialize_settlement(settlement) for settlement in settlements]
    finally:
        session.close()


@app.post("/groups/{group_id}/settlements")
def create_settlement(group_id: int, payload: SettlementCreateInput, request: Request):
    session = SessionLocal()
    try:
        enforce_rate_limit(request, "settlement_create")
        sync_group_lifecycle(session)
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(joinedload(Group.members).joinedload(GroupMember.user))
            .first()
        )
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")
        ensure_group_active(group)

        validate_group_member_ids(group, [payload.actor_id, payload.from_user_id, payload.to_user_id])
        if payload.from_user_id == payload.to_user_id:
            raise HTTPException(status_code=400, detail="La liquidacion manual necesita dos usuarios distintos.")

        amount_cents = amount_to_cents(payload.amount)
        enforce_amount_limit(amount_cents, "La liquidacion")

        settlement = Settlement(
            group_id=group_id,
            from_user_id=payload.from_user_id,
            to_user_id=payload.to_user_id,
            amount_cents=amount_cents,
            notes=payload.notes.strip(),
            created_by=payload.actor_id,
            from_confirmed=payload.actor_id == payload.from_user_id,
            to_confirmed=payload.actor_id == payload.to_user_id,
            received_confirmed=payload.actor_id == payload.from_user_id and payload.actor_id == payload.to_user_id,
        )
        session.add(settlement)

        from_member = next(member.user for member in group.members if member.user_id == payload.from_user_id)
        to_member = next(member.user for member in group.members if member.user_id == payload.to_user_id)
        add_feed_event(
            session,
            group_id,
            payload.actor_id,
            "manual_settlement",
            f"{from_member.username} marco una liquidacion manual a favor de {to_member.username} por ${payload.amount:.2f}. Falta confirmacion de ambas partes.",
        )
        session.commit()

        settlement = (
            session.query(Settlement)
            .filter(Settlement.id == settlement.id)
            .options(
                joinedload(Settlement.from_user),
                joinedload(Settlement.to_user),
                joinedload(Settlement.creator),
            )
            .first()
        )
        return serialize_settlement(settlement)
    finally:
        session.close()


@app.post("/settlements/{settlement_id}/confirm")
def confirm_settlement(settlement_id: int, payload: SettlementConfirmInput):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        settlement = (
            session.query(Settlement)
            .filter(Settlement.id == settlement_id)
            .options(
                joinedload(Settlement.group).joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Settlement.from_user),
                joinedload(Settlement.to_user),
                joinedload(Settlement.creator),
                joinedload(Settlement.confirmer),
            )
            .first()
        )
        if not settlement:
            raise HTTPException(status_code=404, detail="Liquidacion no encontrada.")

        ensure_group_member(settlement.group, payload.actor_id)
        ensure_group_active(settlement.group)
        if payload.actor_id not in {settlement.from_user_id, settlement.to_user_id}:
            raise HTTPException(status_code=403, detail="Solo las dos partes de la liquidacion pueden confirmarla.")
        if settlement.received_confirmed:
            raise HTTPException(status_code=400, detail="Esta liquidacion ya fue confirmada.")

        if payload.actor_id == settlement.from_user_id:
            if settlement.from_confirmed:
                raise HTTPException(status_code=400, detail="Ya confirmaste esta liquidacion.")
            settlement.from_confirmed = True
        if payload.actor_id == settlement.to_user_id:
            if settlement.to_confirmed:
                raise HTTPException(status_code=400, detail="Ya confirmaste esta liquidacion.")
            settlement.to_confirmed = True

        if settlement.from_confirmed and settlement.to_confirmed:
            settlement.received_confirmed = True
            settlement.received_confirmed_at = datetime.utcnow().isoformat()
            settlement.received_confirmed_by = payload.actor_id
        add_feed_event(
            session,
            settlement.group_id,
            payload.actor_id,
            "settlement_confirmed",
            f"{display_name_for_user(settlement.from_user)} y {display_name_for_user(settlement.to_user)} actualizaron la confirmacion de una liquidacion.",
        )
        session.commit()

        settlement = (
            session.query(Settlement)
            .filter(Settlement.id == settlement_id)
            .options(
                joinedload(Settlement.from_user),
                joinedload(Settlement.to_user),
                joinedload(Settlement.creator),
                joinedload(Settlement.confirmer),
            )
            .first()
        )
        return serialize_settlement(settlement)
    finally:
        session.close()


@app.get("/groups/{group_id}/proposals")
def list_group_proposals(group_id: int):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(joinedload(Group.members).joinedload(GroupMember.user))
            .first()
        )
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")

        proposals = (
            session.query(Proposal)
            .filter(Proposal.group_id == group_id)
            .options(
                joinedload(Proposal.creator),
                joinedload(Proposal.payer_user),
                joinedload(Proposal.votes).joinedload(ProposalVote.user),
            )
            .order_by(Proposal.created_at.desc())
            .all()
        )
        return [serialize_proposal(proposal, len(group.members)) for proposal in proposals]
    finally:
        session.close()


@app.post("/groups/{group_id}/proposals")
def create_group_proposal(group_id: int, payload: ProposalCreateInput, request: Request):
    session = SessionLocal()
    try:
        enforce_rate_limit(request, "proposal_create")
        sync_group_lifecycle(session)
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(joinedload(Group.members).joinedload(GroupMember.user))
            .first()
        )
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")
        ensure_group_active(group)

        member_ids = [payload.creator_id]
        if payload.payer_user_id:
            member_ids.append(payload.payer_user_id)
        validate_group_member_ids(group, member_ids)

        total_amount_cents = amount_to_cents(payload.total_amount)
        enforce_amount_limit(total_amount_cents, "El total del servicio")
        provider_url = validate_optional_url(payload.provider_url)
        vote_deadline = normalize_datetime_string(payload.vote_deadline)
        if vote_deadline and not parse_datetime_string(vote_deadline):
            raise HTTPException(status_code=400, detail="La fecha limite de votacion no es valida.")

        proposal = Proposal(
            group_id=group_id,
            creator_id=payload.creator_id,
            payer_user_id=payload.payer_user_id,
            title=payload.title.strip(),
            details=payload.details.strip(),
            activity_type=validate_activity_type(payload.activity_type),
            availability_text=payload.availability_text.strip(),
            provider_name=payload.provider_name.strip(),
            provider_details=payload.provider_details.strip(),
            provider_url=provider_url,
            payment_due_date=payload.payment_due_date.strip(),
            scheduled_for_date=payload.scheduled_for_date.strip(),
            vote_deadline=vote_deadline,
            total_amount_cents=total_amount_cents,
            payment_method=payload.payment_method.strip(),
            confirmation_status=validate_confirmation_status(payload.confirmation_status),
            is_shared_debt=payload.is_shared_debt,
        )
        session.add(proposal)

        creator = next(member.user for member in group.members if member.user_id == payload.creator_id)
        add_feed_event(
            session,
            group_id,
            payload.creator_id,
            "proposal_created",
            f"{creator.username} propuso '{proposal.title}' como {proposal.activity_type}.",
        )
        session.commit()

        proposal = (
            session.query(Proposal)
            .filter(Proposal.id == proposal.id)
            .options(
                joinedload(Proposal.creator),
                joinedload(Proposal.payer_user),
                joinedload(Proposal.votes).joinedload(ProposalVote.user),
            )
            .first()
        )
        return serialize_proposal(proposal, len(group.members))
    finally:
        session.close()


@app.post("/proposals/{proposal_id}/vote")
def vote_proposal(proposal_id: int, payload: ProposalVoteInput):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        proposal = (
            session.query(Proposal)
            .filter(Proposal.id == proposal_id)
            .options(
                joinedload(Proposal.group).joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Proposal.creator),
                joinedload(Proposal.payer_user),
                joinedload(Proposal.votes).joinedload(ProposalVote.user),
            )
            .first()
        )
        if not proposal:
            raise HTTPException(status_code=404, detail="Propuesta no encontrada.")
        ensure_group_member(proposal.group, payload.user_id)
        ensure_group_active(proposal.group)
        vote_deadline = parse_datetime_string(proposal.vote_deadline)
        if vote_deadline and vote_deadline < datetime.utcnow():
            raise HTTPException(status_code=400, detail="La votacion para esta propuesta ya cerro.")
        if any(vote.user_id == payload.user_id for vote in proposal.votes):
            raise HTTPException(status_code=400, detail="Ese usuario ya voto esta propuesta.")

        session.add(ProposalVote(proposal_id=proposal.id, user_id=payload.user_id))
        add_feed_event(
            session,
            proposal.group_id,
            payload.user_id,
            "proposal_vote",
            f"Se sumo un voto a la propuesta '{proposal.title}'.",
        )
        session.commit()

        proposal = (
            session.query(Proposal)
            .filter(Proposal.id == proposal.id)
            .options(
                joinedload(Proposal.creator),
                joinedload(Proposal.payer_user),
                joinedload(Proposal.votes).joinedload(ProposalVote.user),
                joinedload(Proposal.group).joinedload(Group.members).joinedload(GroupMember.user),
            )
            .first()
        )
        return serialize_proposal(proposal, len(proposal.group.members))
    finally:
        session.close()


@app.post("/proposals/{proposal_id}/select")
def select_proposal(proposal_id: int, payload: ProposalSelectInput):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        proposal = (
            session.query(Proposal)
            .filter(Proposal.id == proposal_id)
            .options(
                joinedload(Proposal.group).joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Proposal.creator),
                joinedload(Proposal.payer_user),
                joinedload(Proposal.votes).joinedload(ProposalVote.user),
            )
            .first()
        )
        if not proposal:
            raise HTTPException(status_code=404, detail="Propuesta no encontrada.")

        ensure_group_active(proposal.group)
        ensure_group_host(proposal.group, payload.user_id)

        group_proposals = session.query(Proposal).filter(Proposal.group_id == proposal.group_id).all()
        for item in group_proposals:
            item.status = "selected" if item.id == proposal.id else "open"

        add_feed_event(
            session,
            proposal.group_id,
            payload.user_id,
            "proposal_selected",
            f"El anfitrion eligio '{proposal.title}' como propuesta ganadora.",
        )
        session.commit()

        proposal = (
            session.query(Proposal)
            .filter(Proposal.id == proposal.id)
            .options(
                joinedload(Proposal.creator),
                joinedload(Proposal.payer_user),
                joinedload(Proposal.votes).joinedload(ProposalVote.user),
                joinedload(Proposal.group).joinedload(Group.members).joinedload(GroupMember.user),
            )
            .first()
        )
        return serialize_proposal(proposal, len(proposal.group.members))
    finally:
        session.close()


@app.get("/groups/{group_id}/ratings")
def list_group_ratings(group_id: int):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(
                joinedload(Group.ratings).joinedload(UserRating.rater),
                joinedload(Group.ratings).joinedload(UserRating.rated_user),
            )
            .first()
        )
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")
        return build_ratings_payload(group)
    finally:
        session.close()


@app.post("/groups/{group_id}/ratings")
def create_group_rating(group_id: int, payload: RatingCreateInput):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(joinedload(Group.members).joinedload(GroupMember.user))
            .first()
        )
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")
        ensure_group_active(group)

        validate_group_member_ids(group, [payload.rater_id, payload.rated_user_id])
        if payload.rater_id == payload.rated_user_id:
            raise HTTPException(status_code=400, detail="No puedes calificarte a ti mismo.")

        rating = (
            session.query(UserRating)
            .filter(
                UserRating.group_id == group_id,
                UserRating.rater_id == payload.rater_id,
                UserRating.rated_user_id == payload.rated_user_id,
            )
            .first()
        )
        if rating:
            rating.score = payload.score
            rating.title = payload.title.strip()
            rating.comment = payload.comment.strip()
        else:
            rating = UserRating(
                group_id=group_id,
                rater_id=payload.rater_id,
                rated_user_id=payload.rated_user_id,
                score=payload.score,
                title=payload.title.strip(),
                comment=payload.comment.strip(),
            )
            session.add(rating)

        rated_user = next(member.user for member in group.members if member.user_id == payload.rated_user_id)
        add_feed_event(
            session,
            group_id,
            payload.rater_id,
            "user_rating",
            f"Se actualizo la calificacion de {rated_user.username} con el titulo '{payload.title.strip()}'.",
        )
        session.commit()

        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(
                joinedload(Group.ratings).joinedload(UserRating.rater),
                joinedload(Group.ratings).joinedload(UserRating.rated_user),
            )
            .first()
        )
        return build_ratings_payload(group)
    finally:
        session.close()


@app.get("/groups/{group_id}/stats")
def get_group_stats(group_id: int):
    session = SessionLocal()
    try:
        sync_group_lifecycle(session)
        group = (
            session.query(Group)
            .filter(Group.id == group_id)
            .options(
                joinedload(Group.members).joinedload(GroupMember.user),
                joinedload(Group.expenses).joinedload(Expense.payer),
                joinedload(Group.proposals).joinedload(Proposal.votes),
                joinedload(Group.proposals).joinedload(Proposal.creator),
                joinedload(Group.proposals).joinedload(Proposal.payer_user),
                joinedload(Group.settlements).joinedload(Settlement.creator),
                joinedload(Group.ratings).joinedload(UserRating.rated_user),
            )
            .first()
        )
        if not group:
            raise HTTPException(status_code=404, detail="Grupo no encontrado.")
        return build_group_stats_payload(group)
    finally:
        session.close()


if WEB_DIR.exists():
    app.mount("/app", StaticFiles(directory=WEB_DIR, html=True), name="web-app")
