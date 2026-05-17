-- =============================================================================
-- FırınNet V1 P1-D — Private Group Join Requests + In-App Notifications
-- =============================================================================
-- Önceki davranış: `social_groups_select_visible` policy, private grupları
-- non-member/non-owner kullanıcılardan tamamen gizliyordu. Yeni ürün kararı:
-- private gruplar **listede görünür** olur; içerik (group_messages) yine
-- gated kalır; kullanıcı "Katılma isteği gönder" ile RPC çağırır; grup owner
-- in-app notifications üzerinden bildirim alır, onaylar/reddeder.
--
-- Bu migration:
--   1) social_groups SELECT policy'sini "discoverable but content gated" yapar.
--   2) public.group_join_requests tablosunu ekler (RLS okuma; yazma sadece RPC).
--   3) public.notifications tablosunu ekler (RLS recipient-only; yazma sadece RPC).
--   4) İki RPC ekler: request_group_join + decide_group_join_request.
--   5) İndeksleri + updated_at trigger'ını + comment'ları kurar.
--
-- group_messages SELECT policy ve diğer tablolar dokunulmaz. Public group
-- doğrudan join akışı (`join_group` benzeri eski client davranışı) bozulmaz.
-- =============================================================================

-- 1) social_groups SELECT policy — discoverable but content gated
-- -----------------------------------------------------------------------------
-- Eski policy non-deleted private grupları, owner ve üye olmayanlara gizliyordu.
-- Yeni policy yalnız `is_deleted=false` koşulunu tutar; private gruplar
-- listede görünür; mesaj erişimi ayrıca `group_messages_select_visible`
-- policy'sinde gated kalmaya devam eder.
DROP POLICY IF EXISTS social_groups_select_visible ON public.social_groups;

CREATE POLICY social_groups_select_visible
  ON public.social_groups
  FOR SELECT
  TO authenticated
  USING (is_deleted = false);

COMMENT ON POLICY social_groups_select_visible ON public.social_groups IS
  'V1 P1-D: discoverable private groups. İçerik (mesajlar) ayrı RLS ile gated.';


-- 2) Tablo: public.group_join_requests
-- -----------------------------------------------------------------------------
-- Private gruba katılım isteği. Yalnız RPC üzerinden oluşur/güncellenir;
-- doğrudan INSERT/UPDATE/DELETE PostgreSQL default-deny ile bloklu kalır.
CREATE TABLE public.group_join_requests (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id     uuid NOT NULL REFERENCES public.social_groups(id) ON DELETE CASCADE,
  requester_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status       text NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  message      text,
  decided_by   uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  decided_at   timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- (group_id, requester_id) tekildir — request_group_join RPC mevcut satırı
-- pending'e çekerek tekrar talep ediyor; yeni satır eklemiyor.
CREATE UNIQUE INDEX group_join_requests_group_requester_unique
  ON public.group_join_requests (group_id, requester_id);

CREATE INDEX group_join_requests_group_status_idx
  ON public.group_join_requests (group_id, status);

CREATE INDEX group_join_requests_requester_status_idx
  ON public.group_join_requests (requester_id, status);

ALTER TABLE public.group_join_requests ENABLE ROW LEVEL SECURITY;

-- SELECT: requester kendi satırını görür; grup owner kendi grubuna gelen
-- istekleri görür. Başka authenticated kullanıcı görmez.
CREATE POLICY group_join_requests_select_visible
  ON public.group_join_requests
  FOR SELECT
  TO authenticated
  USING (
    requester_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.social_groups g
      WHERE g.id = group_join_requests.group_id
        AND g.owner_id = auth.uid()
    )
  );

-- INSERT/UPDATE/DELETE policy yok → RLS default-deny. Tek yol RPC.

-- updated_at otomatik bump trigger.
CREATE TRIGGER trg_group_join_requests_updated_at
  BEFORE UPDATE ON public.group_join_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.group_join_requests IS
  'Private gruplara katılım istekleri. Yalnız request_group_join + decide_group_join_request RPC üzerinden yönetilir; doğrudan INSERT/UPDATE/DELETE bloklu.';


-- 3) Tablo: public.notifications
-- -----------------------------------------------------------------------------
-- Uygulama içi bildirim merkezi. Read-only API client; INSERT yalnız
-- SECURITY DEFINER RPC üzerinden gerçekleşir. recipient kendi satırlarını
-- görür ve `read_at` alanını güncelleyebilir.
CREATE TABLE public.notifications (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  actor_id     uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  type         text NOT NULL,
  title        text NOT NULL,
  body         text NOT NULL,
  entity_type  text,
  entity_id    uuid,
  route        text,
  metadata     jsonb NOT NULL DEFAULT '{}'::jsonb,
  read_at      timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX notifications_recipient_created_idx
  ON public.notifications (recipient_id, created_at DESC);

-- Unread sayacını O(unread) yapan partial index.
CREATE INDEX notifications_unread_idx
  ON public.notifications (recipient_id) WHERE read_at IS NULL;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY notifications_select_own
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (recipient_id = auth.uid());

CREATE POLICY notifications_update_own
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (recipient_id = auth.uid())
  WITH CHECK (recipient_id = auth.uid());

-- INSERT/DELETE policy yok → default-deny. Insert sadece RPC ile.

COMMENT ON TABLE public.notifications IS
  'V1 P1-D in-app notifications. Recipient SELECT/UPDATE; INSERT/DELETE bloklu (yalnız SECURITY DEFINER RPC).';


-- 4) RPC: request_group_join
-- -----------------------------------------------------------------------------
-- Auth'lu kullanıcı private bir gruba katılma isteği gönderir.
--
-- Validasyonlar:
--   - auth.uid() null → exception 'auth_required'
--   - group bulunmazsa → 'group_not_found'
--   - group is_deleted → 'group_not_found'
--   - group is_private = false → 'group_is_public' (client direct join kullanmalı)
--   - caller group owner → 'owner_cannot_request'
--   - caller zaten üye → 'already_member'
--
-- Davranış:
--   - Mevcut pending satır varsa → onu döner (idempotent)
--   - Mevcut rejected/cancelled satır varsa → pending'e çeker
--   - Aksi halde yeni satır oluşturur
--   - Grup owner için notification kaydı oluşturur
--
-- Geri dönüş: güncel group_join_requests satırı.
CREATE OR REPLACE FUNCTION public.request_group_join(
  p_group_id uuid,
  p_message  text DEFAULT NULL
)
RETURNS public.group_join_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_user_id  uuid := auth.uid();
  v_group    public.social_groups%ROWTYPE;
  v_existing public.group_join_requests%ROWTYPE;
  v_now      timestamptz := now();
  v_actor    text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_group
  FROM public.social_groups
  WHERE id = p_group_id AND is_deleted = false;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'group_not_found' USING ERRCODE = 'P0002';
  END IF;

  IF v_group.is_private = false THEN
    RAISE EXCEPTION 'group_is_public' USING ERRCODE = 'P0001';
  END IF;

  IF v_group.owner_id = v_user_id THEN
    RAISE EXCEPTION 'owner_cannot_request' USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND owner_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'already_member' USING ERRCODE = 'P0001';
  END IF;

  -- Mevcut satırı yakala
  SELECT * INTO v_existing
  FROM public.group_join_requests
  WHERE group_id = p_group_id AND requester_id = v_user_id;

  IF FOUND THEN
    IF v_existing.status = 'pending' THEN
      RETURN v_existing;
    END IF;
    UPDATE public.group_join_requests
       SET status = 'pending',
           message = COALESCE(p_message, message),
           decided_by = NULL,
           decided_at = NULL,
           updated_at = v_now
     WHERE id = v_existing.id
     RETURNING * INTO v_existing;
  ELSE
    INSERT INTO public.group_join_requests(group_id, requester_id, message)
    VALUES (p_group_id, v_user_id, p_message)
    RETURNING * INTO v_existing;
  END IF;

  -- Notification: grup owner'ına yeni katılım isteği
  SELECT COALESCE(display_name, 'Bir kullanıcı') INTO v_actor
  FROM public.profiles WHERE id = v_user_id;

  INSERT INTO public.notifications(
    recipient_id, actor_id, type, title, body,
    entity_type, entity_id, route, metadata
  ) VALUES (
    v_group.owner_id,
    v_user_id,
    'group_join_request',
    'Yeni katılım isteği',
    v_actor || ' "' || v_group.name || '" grubuna katılmak istiyor.',
    'group',
    v_group.id,
    '/groups/' || v_group.id::text,
    jsonb_build_object(
      'request_id', v_existing.id,
      'group_name', v_group.name
    )
  );

  RETURN v_existing;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.request_group_join(uuid, text) FROM public;
GRANT  EXECUTE ON FUNCTION public.request_group_join(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.request_group_join(uuid, text) IS
  'V1 P1-D: Private grup için katılma isteği oluşturur (idempotent); group owner için notification yaratır.';


-- 5) RPC: decide_group_join_request
-- -----------------------------------------------------------------------------
-- Grup owner pending bir isteği onaylar veya reddeder.
--
-- Validasyonlar:
--   - auth.uid() null → 'auth_required'
--   - request bulunmazsa → 'request_not_found'
--   - request status != 'pending' → 'request_not_pending'
--   - group bulunmazsa/silindi → 'group_not_found'
--   - caller group owner değilse → 'not_group_owner'
--
-- approve=true → request approved + group_members'a member olarak eklenir
-- (ON CONFLICT DO NOTHING) + requester'a "approved" notification.
-- approve=false → request rejected + requester'a "rejected" notification.
CREATE OR REPLACE FUNCTION public.decide_group_join_request(
  p_request_id uuid,
  p_approve    boolean
)
RETURNS public.group_join_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_req     public.group_join_requests%ROWTYPE;
  v_group   public.social_groups%ROWTYPE;
  v_now     timestamptz := now();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_req
  FROM public.group_join_requests
  WHERE id = p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'request_not_found' USING ERRCODE = 'P0002';
  END IF;

  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'request_not_pending' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_group
  FROM public.social_groups
  WHERE id = v_req.group_id;
  IF NOT FOUND OR v_group.is_deleted THEN
    RAISE EXCEPTION 'group_not_found' USING ERRCODE = 'P0002';
  END IF;

  IF v_group.owner_id <> v_user_id THEN
    RAISE EXCEPTION 'not_group_owner' USING ERRCODE = '42501';
  END IF;

  IF p_approve THEN
    UPDATE public.group_join_requests
       SET status = 'approved',
           decided_by = v_user_id,
           decided_at = v_now,
           updated_at = v_now
     WHERE id = p_request_id
     RETURNING * INTO v_req;

    -- group_members ekle — composite PK (group_id, owner_id) conflict'i yutar.
    -- enforce_group_max_members trigger BEFORE INSERT'te group_full atabilir;
    -- bu durumda request approved kalır ama membership başarısız olur. UI/owner
    -- max'ı yükseltebilir veya member kendisi tekrar approve istemine çıkabilir.
    INSERT INTO public.group_members(group_id, owner_id, role)
    VALUES (v_req.group_id, v_req.requester_id, 'member')
    ON CONFLICT (group_id, owner_id) DO NOTHING;

    INSERT INTO public.notifications(
      recipient_id, actor_id, type, title, body,
      entity_type, entity_id, route, metadata
    ) VALUES (
      v_req.requester_id,
      v_user_id,
      'group_join_request_approved',
      'Katılım isteğin onaylandı',
      '"' || v_group.name || '" grubuna katılım isteğin onaylandı.',
      'group',
      v_group.id,
      '/groups/' || v_group.id::text,
      jsonb_build_object(
        'request_id', v_req.id,
        'group_name', v_group.name
      )
    );
  ELSE
    UPDATE public.group_join_requests
       SET status = 'rejected',
           decided_by = v_user_id,
           decided_at = v_now,
           updated_at = v_now
     WHERE id = p_request_id
     RETURNING * INTO v_req;

    INSERT INTO public.notifications(
      recipient_id, actor_id, type, title, body,
      entity_type, entity_id, route, metadata
    ) VALUES (
      v_req.requester_id,
      v_user_id,
      'group_join_request_rejected',
      'Katılım isteğin reddedildi',
      '"' || v_group.name || '" grubu için katılım isteğin reddedildi.',
      'group',
      v_group.id,
      '/groups/' || v_group.id::text,
      jsonb_build_object(
        'request_id', v_req.id,
        'group_name', v_group.name
      )
    );
  END IF;

  RETURN v_req;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.decide_group_join_request(uuid, boolean) FROM public;
GRANT  EXECUTE ON FUNCTION public.decide_group_join_request(uuid, boolean) TO authenticated;

COMMENT ON FUNCTION public.decide_group_join_request(uuid, boolean) IS
  'V1 P1-D: Grup owner pending isteği approve/reject eder; member ekler + requester''e notification yazar.';
