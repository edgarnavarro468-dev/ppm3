from datetime import datetime
from pathlib import Path

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, create_engine
from sqlalchemy.orm import declarative_base, relationship, sessionmaker


BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / "ppm.db"

engine = create_engine(
    f"sqlite:///{DB_PATH}",
    connect_args={"check_same_thread": False},
)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False, expire_on_commit=False)
Base = declarative_base()


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    username = Column(String(120), nullable=False)
    first_name = Column(String(120), default="", nullable=False)
    last_name = Column(String(120), default="", nullable=False)
    email = Column(String(200), unique=True, nullable=False, index=True)
    phone_number = Column(String(40), default="", nullable=False)
    avatar_url = Column(String(500), default="", nullable=False)
    password_hash = Column(String(512), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    memberships = relationship("GroupMember", back_populates="user", cascade="all, delete-orphan")
    paid_expenses = relationship("Expense", back_populates="payer", foreign_keys="Expense.payer_id")
    contacts = relationship(
        "UserContact",
        foreign_keys="UserContact.owner_user_id",
        back_populates="owner",
        cascade="all, delete-orphan",
    )
    contact_of = relationship(
        "UserContact",
        foreign_keys="UserContact.contact_user_id",
        back_populates="contact_user",
        cascade="all, delete-orphan",
    )


class Group(Base):
    __tablename__ = "groups"

    id = Column(Integer, primary_key=True)
    name = Column(String(120), nullable=False)
    description = Column(Text, default="", nullable=False)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(String(20), default="active", nullable=False)
    ends_at = Column(String(40), default="", nullable=False)
    auto_close_action = Column(String(20), default="none", nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    creator = relationship("User", foreign_keys=[created_by])
    members = relationship("GroupMember", back_populates="group", cascade="all, delete-orphan")
    expenses = relationship("Expense", back_populates="group", cascade="all, delete-orphan")
    feed_events = relationship("FeedEvent", back_populates="group", cascade="all, delete-orphan")
    proposals = relationship("Proposal", back_populates="group", cascade="all, delete-orphan")
    settlements = relationship("Settlement", back_populates="group", cascade="all, delete-orphan")
    ratings = relationship("UserRating", back_populates="group", cascade="all, delete-orphan")
    decisions = relationship("GroupDecision", back_populates="group", cascade="all, delete-orphan")


class GroupMember(Base):
    __tablename__ = "group_members"

    id = Column(Integer, primary_key=True)
    group_id = Column(Integer, ForeignKey("groups.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    joined_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    group = relationship("Group", back_populates="members")
    user = relationship("User", back_populates="memberships")


class UserContact(Base):
    __tablename__ = "user_contacts"
    __table_args__ = (UniqueConstraint("owner_user_id", "contact_user_id", name="uq_user_contact_pair"),)

    id = Column(Integer, primary_key=True)
    owner_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    contact_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    nickname = Column(String(120), default="", nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    owner = relationship("User", foreign_keys=[owner_user_id], back_populates="contacts")
    contact_user = relationship("User", foreign_keys=[contact_user_id], back_populates="contact_of")


class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True)
    group_id = Column(Integer, ForeignKey("groups.id"), nullable=False, index=True)
    payer_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    description = Column(String(255), nullable=False)
    amount_cents = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    group = relationship("Group", back_populates="expenses")
    payer = relationship("User", back_populates="paid_expenses", foreign_keys=[payer_id])
    participants = relationship("ExpenseParticipant", back_populates="expense", cascade="all, delete-orphan")


class ExpenseParticipant(Base):
    __tablename__ = "expense_participants"

    id = Column(Integer, primary_key=True)
    expense_id = Column(Integer, ForeignKey("expenses.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    share_cents = Column(Integer, nullable=False)

    expense = relationship("Expense", back_populates="participants")
    user = relationship("User")


class FeedEvent(Base):
    __tablename__ = "feed_events"

    id = Column(Integer, primary_key=True)
    group_id = Column(Integer, ForeignKey("groups.id"), nullable=False, index=True)
    actor_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    event_type = Column(String(60), nullable=False)
    message = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    group = relationship("Group", back_populates="feed_events")
    actor = relationship("User")


class Proposal(Base):
    __tablename__ = "proposals"

    id = Column(Integer, primary_key=True)
    group_id = Column(Integer, ForeignKey("groups.id"), nullable=False, index=True)
    creator_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    payer_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    title = Column(String(160), nullable=False)
    details = Column(Text, default="", nullable=False)
    activity_type = Column(String(40), default="actividad", nullable=False)
    availability_text = Column(Text, default="", nullable=False)
    provider_name = Column(String(160), default="", nullable=False)
    provider_details = Column(Text, default="", nullable=False)
    provider_url = Column(String(500), default="", nullable=False)
    payment_due_date = Column(String(40), default="", nullable=False)
    scheduled_for_date = Column(String(40), default="", nullable=False)
    vote_deadline = Column(String(40), default="", nullable=False)
    total_amount_cents = Column(Integer, nullable=False)
    payment_method = Column(String(80), default="", nullable=False)
    confirmation_status = Column(String(40), default="pendiente", nullable=False)
    is_shared_debt = Column(Boolean, default=True, nullable=False)
    status = Column(String(40), default="open", nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    group = relationship("Group", back_populates="proposals")
    creator = relationship("User", foreign_keys=[creator_id])
    payer_user = relationship("User", foreign_keys=[payer_user_id])
    votes = relationship("ProposalVote", back_populates="proposal", cascade="all, delete-orphan")


class ProposalVote(Base):
    __tablename__ = "proposal_votes"

    id = Column(Integer, primary_key=True)
    proposal_id = Column(Integer, ForeignKey("proposals.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    proposal = relationship("Proposal", back_populates="votes")
    user = relationship("User")


class Settlement(Base):
    __tablename__ = "settlements"

    id = Column(Integer, primary_key=True)
    group_id = Column(Integer, ForeignKey("groups.id"), nullable=False, index=True)
    from_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    to_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    amount_cents = Column(Integer, nullable=False)
    notes = Column(Text, default="", nullable=False)
    received_confirmed = Column(Boolean, default=False, nullable=False)
    received_confirmed_at = Column(String(40), default="", nullable=False)
    received_confirmed_by = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    group = relationship("Group", back_populates="settlements")
    from_user = relationship("User", foreign_keys=[from_user_id])
    to_user = relationship("User", foreign_keys=[to_user_id])
    creator = relationship("User", foreign_keys=[created_by])
    confirmer = relationship("User", foreign_keys=[received_confirmed_by])


class UserRating(Base):
    __tablename__ = "user_ratings"

    id = Column(Integer, primary_key=True)
    group_id = Column(Integer, ForeignKey("groups.id"), nullable=False, index=True)
    rater_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    rated_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    score = Column(Integer, nullable=False)
    title = Column(String(80), default="", nullable=False)
    comment = Column(Text, default="", nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    group = relationship("Group", back_populates="ratings")
    rater = relationship("User", foreign_keys=[rater_id])
    rated_user = relationship("User", foreign_keys=[rated_user_id])


class GroupDecision(Base):
    __tablename__ = "group_decisions"

    id = Column(Integer, primary_key=True)
    group_id = Column(Integer, ForeignKey("groups.id"), nullable=False, index=True)
    requested_by = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    decision_type = Column(String(40), nullable=False)
    target_expense_id = Column(Integer, ForeignKey("expenses.id"), nullable=True, index=True)
    mode = Column(String(20), default="majority", nullable=False)
    status = Column(String(20), default="open", nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    group = relationship("Group", back_populates="decisions")
    requester = relationship("User", foreign_keys=[requested_by])
    target_expense = relationship("Expense")
    votes = relationship("GroupDecisionVote", back_populates="decision", cascade="all, delete-orphan")


class GroupDecisionVote(Base):
    __tablename__ = "group_decision_votes"

    id = Column(Integer, primary_key=True)
    decision_id = Column(Integer, ForeignKey("group_decisions.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    decision = relationship("GroupDecision", back_populates="votes")
    user = relationship("User")


def ensure_sqlite_column(table_name: str, column_name: str, column_sql: str) -> None:
    with engine.begin() as connection:
        columns = {row[1] for row in connection.exec_driver_sql(f"PRAGMA table_info({table_name})").fetchall()}
        if column_name not in columns:
            connection.exec_driver_sql(f"ALTER TABLE {table_name} ADD COLUMN {column_sql}")


Base.metadata.create_all(engine)
ensure_sqlite_column("users", "first_name", "first_name VARCHAR(120) NOT NULL DEFAULT ''")
ensure_sqlite_column("users", "last_name", "last_name VARCHAR(120) NOT NULL DEFAULT ''")
ensure_sqlite_column("users", "phone_number", "phone_number VARCHAR(40) NOT NULL DEFAULT ''")
ensure_sqlite_column("users", "avatar_url", "avatar_url VARCHAR(500) NOT NULL DEFAULT ''")
ensure_sqlite_column("groups", "status", "status VARCHAR(20) NOT NULL DEFAULT 'active'")
ensure_sqlite_column("groups", "ends_at", "ends_at VARCHAR(40) NOT NULL DEFAULT ''")
ensure_sqlite_column("groups", "auto_close_action", "auto_close_action VARCHAR(20) NOT NULL DEFAULT 'none'")
ensure_sqlite_column("proposals", "provider_url", "provider_url VARCHAR(500) NOT NULL DEFAULT ''")
ensure_sqlite_column("proposals", "vote_deadline", "vote_deadline VARCHAR(40) NOT NULL DEFAULT ''")
ensure_sqlite_column("settlements", "received_confirmed", "received_confirmed BOOLEAN NOT NULL DEFAULT 0")
ensure_sqlite_column("settlements", "received_confirmed_at", "received_confirmed_at VARCHAR(40) NOT NULL DEFAULT ''")
ensure_sqlite_column("settlements", "received_confirmed_by", "received_confirmed_by INTEGER")
