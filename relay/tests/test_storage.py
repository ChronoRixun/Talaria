from __future__ import annotations

from sqlalchemy import select

from app.config import Settings
from app.database import Database
from app.models import AuditLog, AuthSession, InboxItem, PushRegistration, User
from app.services import (
    create_inbox_item,
    ensure_default_user,
    list_inbox_items,
    record_audit,
    refresh_auth_session,
    rotate_auth_session,
    upsert_device,
    upsert_push_registration,
)


def make_database(tmp_path):
    settings = Settings(
        environment="test",
        public_base_url="http://testserver/v1",
        database_url=f"sqlite:///{tmp_path / 'relay-storage.db'}",
        internal_api_key="test-internal-key",
    )
    database = Database(settings.database_url)
    database.create_all()
    return settings, database


def test_device_upsert_token_rotation_and_audit(tmp_path):
    settings, database = make_database(tmp_path)

    with database.session() as db:
        user = ensure_default_user(db, settings)
        device = upsert_device(
            db,
            user=user,
            platform="ios",
            installation_id="install-1",
            device_name="Phone",
            device_model="iPhone",
            system_version="26.4",
            app_version="1.0.0",
            build_number="1",
            bundle_id="com.appfactory.HermesMobile",
            environment="development",
        )
        auth_session, access_token, refresh_token = rotate_auth_session(db, settings=settings, user=user, device=device)
        refreshed_session, new_access_token, _ = refresh_auth_session(db, settings=settings, refresh_token=refresh_token)

        record_audit(
            db,
            actor_type="app",
            actor_id=device.id,
            action="device.register",
            entity_type="device",
            entity_id=device.id,
        )
        db.commit()

        assert access_token != new_access_token
        assert auth_session.id == refreshed_session.id
        assert db.scalar(select(AuthSession).where(AuthSession.device_id == device.id)) is not None
        assert db.scalar(select(AuditLog).where(AuditLog.entity_id == device.id)) is not None


def test_push_registration_and_inbox_state_transition(tmp_path):
    settings, database = make_database(tmp_path)

    with database.session() as db:
        user = ensure_default_user(db, settings)
        device = upsert_device(
            db,
            user=user,
            platform="ios",
            installation_id="install-2",
            device_name="Phone",
            device_model="iPhone",
            system_version="26.4",
            app_version="1.0.0",
            build_number="1",
            bundle_id="com.appfactory.HermesMobile",
            environment="development",
        )
        registration = upsert_push_registration(
            db,
            device=device,
            apns_token="deadbeef",
            push_environment="sandbox",
            bundle_id="com.appfactory.HermesMobile",
        )
        item = create_inbox_item(
            db,
            user_id=user.id,
            device_id=device.id,
            kind="approval",
            title="Approve calendar change",
            body="Move dinner to 7 PM.",
            priority="normal",
            payload={"requestId": "calendar-1"},
            expires_at=None,
        )
        db.commit()

        assert db.scalar(select(PushRegistration).where(PushRegistration.id == registration.id)) is not None
        assert db.scalar(select(InboxItem).where(InboxItem.id == item.id)).status == "pending"
        assert len(list_inbox_items(db, user_id=user.id)) == 1
        assert db.scalar(select(User).where(User.id == user.id)) is not None
