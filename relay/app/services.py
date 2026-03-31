from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import Settings
from .hermes_adapter import HermesAdapter, HermesConversationMessage
from .models import AuditLog, AuthSession, Conversation, Device, InboxAction, InboxItem, Message, PushRegistration, User, utcnow
from .security import hash_token, issue_tokens, normalize_datetime


def ensure_default_user(db: Session, settings: Settings) -> User:
    user = db.scalar(select(User).limit(1))
    if user is None:
        user = User(display_name=settings.default_user_display_name)
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


def record_audit(
    db: Session,
    *,
    actor_type: str,
    action: str,
    entity_type: str,
    actor_id: str | None = None,
    entity_id: str | None = None,
    payload: dict | None = None,
) -> None:
    db.add(
        AuditLog(
            actor_type=actor_type,
            actor_id=actor_id,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            payload=payload,
        )
    )


def upsert_device(
    db: Session,
    *,
    user: User,
    platform: str,
    installation_id: str,
    device_name: str,
    device_model: str,
    system_version: str,
    app_version: str,
    build_number: str,
    bundle_id: str,
    environment: str,
) -> Device:
    device = db.scalar(select(Device).where(Device.installation_id == installation_id))

    if device is None:
        device = Device(
            user_id=user.id,
            platform=platform,
            installation_id=installation_id,
            device_name=device_name,
            device_model=device_model,
            system_version=system_version,
            app_version=app_version,
            build_number=build_number,
            bundle_id=bundle_id,
            environment=environment,
            last_seen_at=utcnow(),
        )
        db.add(device)
    else:
        device.user_id = user.id
        device.platform = platform
        device.device_name = device_name
        device.device_model = device_model
        device.system_version = system_version
        device.app_version = app_version
        device.build_number = build_number
        device.bundle_id = bundle_id
        device.environment = environment
        device.last_seen_at = utcnow()

    db.commit()
    db.refresh(device)
    return device


def rotate_auth_session(db: Session, *, settings: Settings, user: User, device: Device) -> tuple[AuthSession, str, str]:
    access_token, refresh_token, access_expires_at, refresh_expires_at = issue_tokens(settings)
    auth_session = db.scalar(
        select(AuthSession).where(
            AuthSession.device_id == device.id,
            AuthSession.revoked_at.is_(None),
        )
    )

    if auth_session is None:
        auth_session = AuthSession(
            user_id=user.id,
            device_id=device.id,
            access_token_hash=hash_token(access_token),
            refresh_token_hash=hash_token(refresh_token),
            access_expires_at=access_expires_at,
            refresh_expires_at=refresh_expires_at,
        )
        db.add(auth_session)
    else:
        auth_session.user_id = user.id
        auth_session.access_token_hash = hash_token(access_token)
        auth_session.refresh_token_hash = hash_token(refresh_token)
        auth_session.access_expires_at = access_expires_at
        auth_session.refresh_expires_at = refresh_expires_at
        auth_session.revoked_at = None

    db.commit()
    db.refresh(auth_session)
    return auth_session, access_token, refresh_token


def refresh_auth_session(db: Session, *, settings: Settings, refresh_token: str) -> tuple[AuthSession, str, str]:
    auth_session = db.scalar(
        select(AuthSession).where(
            AuthSession.refresh_token_hash == hash_token(refresh_token),
            AuthSession.revoked_at.is_(None),
        )
    )

    if auth_session is None or normalize_datetime(auth_session.refresh_expires_at) < utcnow():
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token.")

    user = db.get(User, auth_session.user_id)
    device = db.get(Device, auth_session.device_id)
    if user is None or device is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid auth session.")

    return rotate_auth_session(db, settings=settings, user=user, device=device)


def upsert_push_registration(
    db: Session,
    *,
    device: Device,
    apns_token: str,
    push_environment: str,
    bundle_id: str,
) -> PushRegistration:
    registration = db.scalar(select(PushRegistration).where(PushRegistration.device_id == device.id))

    if registration is None:
        registration = PushRegistration(
            device_id=device.id,
            apns_token=apns_token,
            push_environment=push_environment,
            bundle_id=bundle_id,
            last_registered_at=utcnow(),
        )
        db.add(registration)
    else:
        registration.apns_token = apns_token
        registration.push_environment = push_environment
        registration.bundle_id = bundle_id
        registration.is_active = True
        registration.last_registered_at = utcnow()

    db.commit()
    db.refresh(registration)
    return registration


def create_inbox_item(
    db: Session,
    *,
    user_id: str,
    device_id: str | None,
    kind: str,
    title: str,
    body: str,
    priority: str,
    payload: dict | None,
    expires_at: datetime | None,
) -> InboxItem:
    item = InboxItem(
        user_id=user_id,
        device_id=device_id,
        kind=kind,
        title=title,
        body=body,
        priority=priority,
        payload=payload,
        expires_at=expires_at,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def list_inbox_items(db: Session, *, user_id: str) -> list[InboxItem]:
    items = db.scalars(
        select(InboxItem)
        .where(InboxItem.user_id == user_id)
        .order_by(InboxItem.created_at.desc())
    ).all()
    return list(items)


def record_inbox_action(
    db: Session,
    *,
    item: InboxItem,
    action_id: str,
    actor_type: str,
) -> InboxAction:
    now = utcnow()

    if action_id == "dismiss":
        item.status = "dismissed"
        item.dismissed_at = now
    elif action_id in {"approve", "confirm"}:
        item.status = "completed"
        item.completed_at = now
    else:
        item.status = "opened"
        item.opened_at = now

    item.updated_at = now

    action = InboxAction(
        inbox_item_id=item.id,
        action_id=action_id,
        actor_type=actor_type,
        result={"status": item.status},
    )
    db.add(action)
    db.commit()
    db.refresh(action)
    db.refresh(item)
    return action


def get_inbox_item_for_user(db: Session, *, item_id: str, user_id: str) -> InboxItem:
    item = db.scalar(select(InboxItem).where(InboxItem.id == item_id, InboxItem.user_id == user_id))
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inbox item not found.")
    return item


def list_inbox_actions(db: Session, *, item_id: str) -> list[InboxAction]:
    return list(
        db.scalars(
            select(InboxAction)
            .where(InboxAction.inbox_item_id == item_id)
            .order_by(InboxAction.created_at.asc())
        ).all()
    )


def default_action_titles(kind: str) -> tuple[str | None, str | None]:
    if kind == "approval":
        return "Approve", "Dismiss"
    if kind in {"suggestion", "notification", "alert", "reminder"}:
        return "Open", "Dismiss"
    return None, "Dismiss"


def get_or_create_current_conversation(db: Session, *, user_id: str) -> Conversation:
    conversation = db.scalar(
        select(Conversation).where(
            Conversation.user_id == user_id,
            Conversation.is_archived.is_(False),
        )
    )

    if conversation is None:
        conversation = Conversation(user_id=user_id, title="Hermes")
        db.add(conversation)
        db.commit()
        db.refresh(conversation)

    return conversation


def list_conversation_messages(db: Session, *, conversation_id: str) -> list[Message]:
    return list(
        db.scalars(
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.created_at.asc())
        ).all()
    )


def append_message(
    db: Session,
    *,
    conversation: Conversation,
    user_id: str,
    role: str,
    text: str,
    client_message_id: str | None = None,
    delivery_status: str | None = None,
) -> Message:
    message = Message(
        conversation_id=conversation.id,
        user_id=user_id,
        role=role,
        text=text,
        client_message_id=client_message_id,
        delivery_status=delivery_status,
    )
    conversation.last_message_at = utcnow()
    conversation.updated_at = utcnow()
    db.add(message)
    db.commit()
    db.refresh(message)
    db.refresh(conversation)
    return message


def generate_hermes_reply(
    *,
    adapter: HermesAdapter,
    latest_user_message: str,
    history: list[Message],
) -> str:
    replay_history = [
        HermesConversationMessage(role=message.role, text=message.text)
        for message in history
    ]
    result = adapter.send_message(
        latest_user_message=latest_user_message,
        history=replay_history,
    )
    return result.text


def serialize_message(message: Message) -> dict:
    return {
        "id": message.id,
        "role": message.role,
        "text": message.text,
        "timestamp": message.created_at,
    }


def serialize_conversation(conversation: Conversation, messages: list[Message]) -> dict:
    return {
        "id": conversation.id,
        "title": conversation.title,
        "updatedAt": conversation.updated_at,
        "messages": [serialize_message(message) for message in messages],
    }


def serialize_inbox_item(item: InboxItem) -> dict:
    primary_title, secondary_title = default_action_titles(item.kind)
    return {
        "id": uuid.UUID(item.id),
        "kind": item.kind,
        "title": item.title,
        "body": item.body,
        "priority": item.priority,
        "status": item.status,
        "payload": item.payload or None,
        "createdAt": item.created_at,
        "primaryActionTitle": primary_title,
        "secondaryActionTitle": secondary_title,
    }
