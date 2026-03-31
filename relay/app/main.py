from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import datetime, timezone
import uuid

from fastapi import Depends, FastAPI, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import Settings
from .database import Database
from .hermes_adapter import build_hermes_adapter
from .models import PushRegistration
from .schemas import DeviceRegisterRequest, InboxActionRequest, InternalInboxCreateRequest, MessageCreateRequest, PushRegisterRequest, RefreshRequest
from .security import AuthContext, get_auth_context, get_db, get_settings, require_internal_key
from .services import (
    create_inbox_item,
    ensure_default_user,
    generate_hermes_reply,
    get_inbox_item_for_user,
    get_or_create_current_conversation,
    list_inbox_actions,
    list_conversation_messages,
    list_inbox_items,
    record_audit,
    record_inbox_action,
    refresh_auth_session,
    rotate_auth_session,
    append_message,
    serialize_conversation,
    serialize_inbox_item,
    upsert_device,
    upsert_push_registration,
)


def success(data: dict) -> dict:
    return {
        "data": data,
        "meta": {
            "requestId": str(uuid.uuid4()),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        },
    }


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings.from_env()
    database = Database(settings.database_url)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        database.create_all()
        yield

    app = FastAPI(title=settings.service_name, version=settings.version, lifespan=lifespan)
    app.state.settings = settings
    app.state.database = database
    app.state.hermes_adapter = build_hermes_adapter(settings)

    @app.get("/v1/health")
    def health() -> dict:
        return success({"status": "ok"})

    @app.get("/v1/version")
    def version(request_settings: Settings = Depends(get_settings)) -> dict:
        return success(
            {
                "service": request_settings.service_name,
                "version": request_settings.version,
                "environment": request_settings.environment,
            }
        )

    @app.post("/v1/device/register")
    def register_device(
        payload: DeviceRegisterRequest,
        db: Session = Depends(get_db),
        request_settings: Settings = Depends(get_settings),
    ) -> dict:
        user = ensure_default_user(db, request_settings)
        device = upsert_device(
            db,
            user=user,
            platform=payload.device.platform,
            installation_id=str(payload.device.installationId),
            device_name=payload.device.deviceName,
            device_model=payload.device.deviceModel,
            system_version=payload.device.systemVersion,
            app_version=payload.device.appVersion,
            build_number=payload.device.buildNumber,
            bundle_id=payload.device.bundleId,
            environment=payload.client.environment,
        )
        auth_session, access_token, refresh_token = rotate_auth_session(
            db,
            settings=request_settings,
            user=user,
            device=device,
        )

        record_audit(
            db,
            actor_type="app",
            actor_id=device.id,
            action="device.register",
            entity_type="device",
            entity_id=device.id,
            payload={"installationId": str(payload.device.installationId)},
        )
        db.commit()

        return success(
            {
                "deviceId": device.id,
                "deviceRegistered": True,
                "session": {
                    "connectionStatus": "connected",
                    "isMockMode": False,
                    "backendEndpoint": request_settings.public_base_url,
                    "lastSyncAt": None,
                },
                "auth": {
                    "accessToken": access_token,
                    "refreshToken": refresh_token,
                    "expiresAt": auth_session.access_expires_at,
                },
            }
        )

    @app.get("/v1/session")
    def session(
        auth: AuthContext = Depends(get_auth_context),
        db: Session = Depends(get_db),
        request_settings: Settings = Depends(get_settings),
    ) -> dict:
        push_registered = db.scalar(
            select(PushRegistration).where(
                PushRegistration.device_id == auth.device.id,
                PushRegistration.is_active.is_(True),
            )
        )

        return success(
            {
                "user": {
                    "id": auth.user.id,
                    "displayName": auth.user.display_name,
                },
                "device": {
                    "id": auth.device.id,
                    "registered": True,
                },
                "session": {
                    "connectionStatus": "connected",
                    "isMockMode": False,
                    "backendEndpoint": request_settings.public_base_url,
                    "lastSyncAt": auth.device.last_seen_at,
                },
                "push": {
                    "tokenRegistered": push_registered is not None,
                },
            }
        )

    @app.post("/v1/auth/refresh")
    def refresh_auth(
        payload: RefreshRequest,
        db: Session = Depends(get_db),
        request_settings: Settings = Depends(get_settings),
    ) -> dict:
        auth_session, access_token, refresh_token = refresh_auth_session(
            db,
            settings=request_settings,
            refresh_token=payload.refreshToken,
        )
        record_audit(
            db,
            actor_type="app",
            actor_id=auth_session.device_id,
            action="auth.refresh",
            entity_type="auth_session",
            entity_id=auth_session.id,
        )
        db.commit()

        return success(
            {
                "accessToken": access_token,
                "refreshToken": refresh_token,
                "expiresAt": auth_session.access_expires_at,
            }
        )

    @app.post("/v1/push/register")
    def register_push(
        payload: PushRegisterRequest,
        auth: AuthContext = Depends(get_auth_context),
        db: Session = Depends(get_db),
    ) -> dict:
        if str(payload.deviceId) != auth.device.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot register push token for another device.")

        registration = upsert_push_registration(
            db,
            device=auth.device,
            apns_token=payload.apnsToken,
            push_environment=payload.pushEnvironment,
            bundle_id=payload.bundleId,
        )
        record_audit(
            db,
            actor_type="app",
            actor_id=auth.device.id,
            action="push.register",
            entity_type="push_registration",
            entity_id=registration.id,
        )
        db.commit()

        return success(
            {
                "registered": True,
                "updatedAt": registration.updated_at,
            }
        )

    @app.get("/v1/conversations/current")
    def current_conversation(auth: AuthContext = Depends(get_auth_context), db: Session = Depends(get_db)) -> dict:
        conversation = get_or_create_current_conversation(db, user_id=auth.user.id)
        messages = list_conversation_messages(db, conversation_id=conversation.id)
        return success({"conversation": serialize_conversation(conversation, messages)})

    @app.post("/v1/messages")
    def create_message(
        payload: MessageCreateRequest,
        auth: AuthContext = Depends(get_auth_context),
        db: Session = Depends(get_db),
    ) -> dict:
        conversation = get_or_create_current_conversation(db, user_id=auth.user.id)
        user_message = append_message(
            db,
            conversation=conversation,
            user_id=auth.user.id,
            role="user",
            text=payload.text,
            client_message_id=str(payload.clientMessageId) if payload.clientMessageId else None,
            delivery_status="sent",
        )

        history = list_conversation_messages(db, conversation_id=conversation.id)
        try:
            hermes_reply = generate_hermes_reply(
                adapter=app.state.hermes_adapter,
                latest_user_message=payload.text,
                history=history[:-1],
            )
        except RuntimeError as error:
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(error)) from error

        assistant_message = append_message(
            db,
            conversation=conversation,
            user_id=auth.user.id,
            role="hermes",
            text=hermes_reply,
            delivery_status="delivered",
        )

        record_audit(
            db,
            actor_type="user",
            actor_id=auth.user.id,
            action="chat.message.create",
            entity_type="conversation",
            entity_id=conversation.id,
        )
        db.commit()

        messages = list_conversation_messages(db, conversation_id=conversation.id)
        return success(
            {
                "conversation": serialize_conversation(conversation, messages),
                "message": {
                    "id": assistant_message.id,
                    "role": assistant_message.role,
                    "text": assistant_message.text,
                    "timestamp": assistant_message.created_at,
                },
                "userMessage": {
                    "id": user_message.id,
                    "role": user_message.role,
                    "text": user_message.text,
                    "timestamp": user_message.created_at,
                },
            }
        )

    @app.get("/v1/inbox")
    def inbox(auth: AuthContext = Depends(get_auth_context), db: Session = Depends(get_db)) -> dict:
        items = [serialize_inbox_item(item) for item in list_inbox_items(db, user_id=auth.user.id)]
        return success({"items": items})

    @app.post("/v1/inbox/{item_id}/action")
    def inbox_action(
        item_id: str,
        payload: InboxActionRequest,
        auth: AuthContext = Depends(get_auth_context),
        db: Session = Depends(get_db),
    ) -> dict:
        item = get_inbox_item_for_user(db, item_id=item_id, user_id=auth.user.id)
        action = record_inbox_action(db, item=item, action_id=payload.actionId, actor_type="user")
        record_audit(
            db,
            actor_type="user",
            actor_id=auth.user.id,
            action=f"inbox.{payload.actionId}",
            entity_type="inbox_item",
            entity_id=item.id,
        )
        db.commit()

        return success(
            {
                "itemID": item.id,
                "actionID": action.action_id,
                "status": item.status,
                "completedAt": action.created_at,
            }
        )

    @app.post("/internal/inbox/create", dependencies=[Depends(require_internal_key)])
    def internal_create_inbox(
        payload: InternalInboxCreateRequest,
        db: Session = Depends(get_db),
        request_settings: Settings = Depends(get_settings),
    ) -> dict:
        user = ensure_default_user(db, request_settings)
        target_user_id = str(payload.userId) if payload.userId else user.id
        target_device_id = str(payload.deviceId) if payload.deviceId else None
        item = create_inbox_item(
            db,
            user_id=target_user_id,
            device_id=target_device_id,
            kind=payload.kind,
            title=payload.title,
            body=payload.body,
            priority=payload.priority,
            payload=payload.payload,
            expires_at=payload.expiresAt,
        )
        record_audit(
            db,
            actor_type="hermes",
            action="internal.inbox.create",
            entity_type="inbox_item",
            entity_id=item.id,
        )
        db.commit()

        return success({"item": serialize_inbox_item(item)})

    @app.get("/internal/inbox/{item_id}/actions", dependencies=[Depends(require_internal_key)])
    def internal_inbox_actions(item_id: str, db: Session = Depends(get_db)) -> dict:
        actions = list_inbox_actions(db, item_id=item_id)
        return success(
            {
                "actions": [
                    {
                        "id": action.id,
                        "actionId": action.action_id,
                        "actorType": action.actor_type,
                        "result": action.result,
                        "createdAt": action.created_at,
                    }
                    for action in actions
                ]
            }
        )

    return app


app = create_app()
